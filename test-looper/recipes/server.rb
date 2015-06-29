#
# Cookbook Name:: test-looper-server
# Recipe:: setup
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#
# Creates user accounts, directories, ssh keys, and other
# fairly static resources on the machine


service_account = node[:test_looper][:service_account]
home_dir = node[:test_looper][:home_dir]

install_dir = node[:test_looper_server][:install_dir]
ssh_dir = "#{install_dir}/.ssh"
deploy_key = "#{ssh_dir}/#{node[:test_looper_server][:github_deploy_key]}"

tasks_root_dir = "#{install_dir}/tasks"
deploy_dir = "#{install_dir}/deploy-src"

config_file = "#{install_dir}/test-looper-server.conf"
src_dir = "#{install_dir}/src"
service_dir = "#{src_dir}/current"
git_ssh_wrapper = "#{ssh_dir}/#{node[:test_looper][:git_ssh_wrapper]}"

log_file = "/var/log/test-looper-server.log"
stack_file = "#{log_file}.stack"


require 'aws-sdk'
s3 = AWS::S3.new
bucket = node[:test_looper][:data_bag_bucket]
data_bag_key = node[:test_looper][:data_bag_key]
encrypted_data_bag = JSON.parse(s3.buckets[bucket].objects[data_bag_key].read)
encrypted_data_bag_key = node[:test_looper][:encrypted_data_bag_key].gsub('\n', "\n").strip
Chef::Log.info("Data bag key: #{encrypted_data_bag_key}")
Chef::Log.info("Raw data bag: #{encrypted_data_bag}")
secrets = Chef::EncryptedDataBagItem.new(encrypted_data_bag, encrypted_data_bag_key)


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

# Create the git ssh key (deployment key)
file deploy_key do
  content secrets['git_deploy_key']
  owner service_account
  group service_account
  mode '0700'
end


# Copy SSL Certificate
ssl_dir = node[:test_looper_server][:ssl_dir]
cert_name = node[:test_looper_server][:ssl_cert_prefix]
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

# Create the git ssh wrapper that uses our deployment key
template git_ssh_wrapper do
  source 'git-ssh-wrapper.erb'
  owner service_account
  group service_account
  mode '0700'
  variables({
      :deploy_key => deploy_key
  })
end

# Create log files and set their ownership
[log_file, stack_file].each do |logfile|
  file logfile do
    owner service_account
    group service_account
  end
end

# Clone the repo into the installation directory
git_branch = node[:test_looper][:git_branch]
deploy_revision src_dir do
  repo node[:test_looper][:git_repo]
  revision git_branch
  ssh_wrapper git_ssh_wrapper
  user service_account
  group service_account
  action :deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end


http_port = node[:test_looper_server][:http_port]
ec2_security_group = node[:test_looper_server][:ec2_worker_security_group]
ec2_looper_ami = node[:test_looper_server][:ec2_worker_ami]
ec2_worker_role_name = node[:test_looper_server][:ec2_worker_role_name]
ec2_worker_ssh_key_name = node[:test_looper_server][:ec2_worker_ssh_key_name]
ec2_worker_root_volume_size_gb = node[:test_looper_server][:ec2_worker_root_volume_size_gb]
ec2_test_result_bucket = node[:test_looper][:test_result_bucket]
worker_install_dir = node[:test_looper_worker][:install_dir]
worker_config_file = "#{worker_install_dir}/#{node[:test_looper_worker][:config_file]}"

template config_file do
  source "test-looper-server.conf.erb"
  owner service_account
  group service_account
  variables({
    :server_port => node[:test_looper_server][:port],
    :server_http_port => http_port,
    :github_app_id => node[:test_looper_server][:github_oauth_app_id],
    :github_app_secret => secrets['test_looper_github_app_client_secret'],
    :github_access_token => secrets['github_api_token'],
    :github_webhook_secret => secrets['test_looper_github_webhook_secret'],
    :github_test_looper_branch => git_branch,
    :ec2_security_group => ec2_security_group,
    :ec2_ami => ec2_looper_ami,
    :ec2_worker_role_name => ec2_worker_role_name,
    :ec2_worker_ssh_key_name => ec2_worker_ssh_key_name,
    :ec2_worker_root_volume_size_gb => ec2_worker_root_volume_size_gb,
    :ec2_test_result_bucket => ec2_test_result_bucket,
    :worker_install_dir => node[:test_looper_worker][:install_dir],
    :worker_config_file => worker_config_file
    })
end

template "/etc/init/test-looper-server.conf" do
  source "test-looper-server-upstart-conf.erb"
  variables({
      :service_account => service_account,
      :service_dir => service_dir,
      :git_ssh_wrapper => git_ssh_wrapper,
      :log_file => log_file,
      :stack_file => stack_file,
      :git_branch => git_branch,
      :tasks_root => tasks_root_dir,
      :deploy_dir => deploy_dir,
      :dependencies_version => node[:test_looper][:expected_dependencies_version],
      :config_file => config_file
  })
end


web_app "test-looper-proxy" do
  template "web_app.conf.erb"
  server_name node[:test_looper_server][:dnsname]
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
