#
# Cookbook Name:: test-looper-server
# Recipe:: setup
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#
# Creates user accounts, directories, ssh keys, and other
# fairly static resources on the machine

node_looper = node[:test_looper]
node_server = node[:test_looper_server]

dnsname = node_server[:dnsname]
Chef::Application.fatal("Missing test_looper_server::dnsname attribute") if dnsname.empty?

encrypted_data_bag_key = node_looper[:encrypted_data_bag_key].gsub('\n', "\n").strip
Chef::Application.fatal("Missing test_looper::encrypted_data_bag_key attribute") if encrypted_data_bag_key.empty?

service_account = node_looper[:service_account]
home_dir = node_looper[:home_dir]

install_dir = node_server[:install_dir]
ssh_dir = "#{install_dir}/.ssh"
deploy_key_looper = "#{ssh_dir}/#{node_looper[:github_deploy_key_looper]}"
deploy_key_target = "#{ssh_dir}/#{node_looper[:github_deploy_key_target]}"

tasks_root_dir = "#{install_dir}/tasks"
deploy_dir = "#{install_dir}/deploy-src"

config_file = "#{install_dir}/test-looper-server.conf"
src_dir = "#{install_dir}/src"
service_dir = "#{src_dir}/current"

target_repo_dir = "#{install_dir}/target_repo"
git_ssh_wrapper_looper = "#{ssh_dir}/#{node_looper[:git_ssh_wrapper_looper_repo]}"
git_ssh_wrapper_target = "#{ssh_dir}/#{node_looper[:git_ssh_wrapper_target_repo]}"

log_file = "/var/log/test-looper-server.log"
stack_file = "#{log_file}.stack"


if node[:no_aws]
  secrets = Chef::EncryptedDataBagItem.load('test-looper', 'server')
else
  require 'aws-sdk'
  s3 = AWS::S3.new
  env = node_looper[:environment] # prod, dev, etc.
  bucket = node_looper[:data_bag_bucket]
  data_bag_key = node_server[:data_bag_key]
  encrypted_data_bag = JSON.parse(s3.buckets[bucket].objects["#{env}/#{data_bag_key}"].read)
  secrets = Chef::EncryptedDataBagItem.new(encrypted_data_bag, encrypted_data_bag_key)
end


# Create a user to run the service
user service_account do
  supports :manage_home => true
  shell '/bin/bash'
  home home_dir
  action :create
end

# Create installation and supporting directories
[install_dir, ssh_dir, tasks_root_dir, deploy_dir].each do |path|
  directory path do
    owner service_account
    group service_account
    action :create
  end
end

# Create the git ssh keys (deployment keys)
file deploy_key_looper do
  content secrets['test_looper_repo_deploy_key']
  owner service_account
  group service_account
  mode '0700'
end
file deploy_key_target do
  content secrets['git_deploy_key']
  owner service_account
  group service_account
  mode '0700'
end


# Copy SSL Certificate
ssl_dir = node_server[:ssl_dir]
cert_name = node_server[:ssl_cert_prefix]
public_cert_file = "#{ssl_dir}/#{cert_name}.crt"
private_key_file = "#{ssl_dir}/#{cert_name}.key"
cert_chain_file = "#{ssl_dir}/#{cert_name}.ca"

ssl_private_key = secrets['ssl_private_key']
ssl_public_cert = secrets['ssl_public_cert']
ssl_chain = secrets['ssl_chain']

file public_cert_file do
  content ssl_public_cert
  owner service_account
  group service_account
  mode '0700'
end
file private_key_file do
  content ssl_private_key
  owner service_account
  group service_account
  mode '0700'
end
file cert_chain_file do
  content ssl_chain
  owner service_account
  group service_account
  mode '0700'
end

# Create the git ssh wrappers that uses our deployment keys
template git_ssh_wrapper_looper do
  source 'git-ssh-wrapper.erb'
  owner service_account
  group service_account
  mode '0700'
  variables({
      :deploy_key => deploy_key_looper
  })
end
template git_ssh_wrapper_target do
  source 'git-ssh-wrapper.erb'
  owner service_account
  group service_account
  mode '0700'
  variables({
      :deploy_key => deploy_key_target
  })
end

# Create log files and set their ownership
[log_file, stack_file].each do |logfile|
  file logfile do
    owner service_account
    group service_account
  end
end
logrotate_app "test-looper-server" do
  path [log_file, stack_file]
  frequency "daily"
  rotate 7
end

# Clone the repo into the installation directory
looper_branch = node_looper[:looper_branch]
deploy_revision src_dir do
  repo node_looper[:looper_repo]
  revision looper_branch
  ssh_wrapper git_ssh_wrapper_looper
  user service_account
  group service_account
  action :force_deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end

deploy_revision target_repo_dir do
  repo "git@github.com:#{node_looper[:target_repo_owner]}/#{node_looper[:target_repo]}.git"
  revision "master"
  ssh_wrapper git_ssh_wrapper_target
  user service_account
  group service_account
  action :force_deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end


http_port = node_server[:http_port]
ec2_security_group = node_server[:worker_security_group]
ec2_looper_ami = node_server[:worker_ami]
ec2_worker_role_name = node_server[:ec2_worker_role_name]
ec2_worker_ssh_key_name = node_server[:ec2_worker_ssh_key_name]
ec2_worker_root_volume_size_gb = node_server[:ec2_worker_root_volume_size_gb]
ec2_test_result_bucket = node_looper[:test_results_bucket]
ec2_builds_bucket = node_looper[:builds_bucket]
worker_install_dir = node[:test_looper_worker][:install_dir]
worker_config_file = "#{worker_install_dir}/#{node[:test_looper_worker][:config_file]}"

template config_file do
  source "server-conf.erb"
  owner service_account
  group service_account
  variables({
    :server_port => node_server[:port],
    :server_http_port => http_port,
    :server_tasks_dir => tasks_root_dir,
    :github_app_id => secrets['github_oauth_app_client_id'],
    :github_app_secret => secrets['github_oauth_app_client_secret'],
    :github_access_token => secrets['github_api_token'],
    :github_webhook_secret => secrets['github_webhook_secret'],
    :github_test_looper_branch => looper_branch,
    :github_baseline_branch => node_server[:baseline_branch],
    :github_baseline_depth => node_server[:baseline_depth],
    :github_target_repo => node_looper[:target_repo],
    :github_target_repo_owner => node_looper[:target_repo_owner],
    :github_test_definitions_path => node_server[:test_definitions_path],
    :ec2_security_group => ec2_security_group,
    :ec2_ami => ec2_looper_ami,
    :ec2_worker_role_name => ec2_worker_role_name,
    :ec2_worker_ssh_key_name => ec2_worker_ssh_key_name,
    :ec2_worker_root_volume_size_gb => ec2_worker_root_volume_size_gb,
    :ec2_test_result_bucket => ec2_test_result_bucket,
    :ec2_builds_bucket => ec2_builds_bucket,
    :ec2_vpc_subnets => node_server[:vpc_subnets],
    :worker_install_dir => node[:test_looper_worker][:install_dir],
    :worker_config_file => worker_config_file,
    :worker_core_dump_dir => node[:test_looper_worker][:core_dump_dir]
    })
end

template "/etc/init/test-looper-server.conf" do
  source "server-init.erb"
  variables({
      :service_account => service_account,
      :service_dir => service_dir,
      :git_ssh_wrapper_looper => git_ssh_wrapper_looper,
      :git_ssh_wrapper_target => git_ssh_wrapper_target,
      :target_repo_path => "#{target_repo_dir}/current",
      :log_file => log_file,
      :stack_file => stack_file,
      :looper_branch => looper_branch,
      :deploy_dir => deploy_dir,
      :dependencies_version => node_looper[:expected_dependencies_version],
      :config_file => config_file,
      :command_options => node_server[:command_options]
  })
end


web_app "test-looper-proxy" do
  template "server-apache-conf.erb"
  server_name node_server[:dnsname]
  cert_file public_cert_file
  cert_key private_key_file
  cert_chain cert_chain_file
  http_port http_port
end

apache_site "test-looper-proxy" do
  enable true
end

service "test-looper-server" do
  action [:stop, :start]
  provider Chef::Provider::Service::Upstart
end

service "apache2" do
  action :restart
end
