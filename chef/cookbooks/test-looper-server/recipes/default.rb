#
# Cookbook Name:: test-looper-server
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'apt'

include_recipe 'apache2'
include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_proxy'
include_recipe 'apache2::mod_proxy_http'

include_recipe 'test-looper-server::apt-packages'
include_recipe 'test-looper-server::python-modules'

service_account = node[:test_looper_server][:service_account]
install_dir = node[:test_looper_server][:install_dir]
ssl_dir = node[:test_looper_server][:ssl_dir]

cert_name = node[:test_looper_server][:ssl_cert_prefix]
public_cert_file = "#{ssl_dir}/#{cert_name}.crt"
private_key_file = "#{ssl_dir}/#{cert_name}.key"
cert_chain_file = "#{ssl_dir}/#{cert_name}.ca"


src_dir = "#{install_dir}/src"
service_dir = "#{src_dir}/current"
ssh_dir = "#{install_dir}/.ssh"
deploy_key = "#{ssh_dir}/#{node[:test_looper_server][:github_deploy_key]}"
git_ssh_wrapper = "#{ssh_dir}/#{node[:test_looper_server][:git_ssh_wrapper]}"
tasks_root_dir = "#{install_dir}/tasks"

dnsname = node[:test_looper_server][:dnsname]
http_port = node[:test_looper_server][:http_port]

git_branch = node[:test_looper_server][:git_branch]

log_file = "/var/log/test-looper-server.log"
stack_file = "#{log_file}.stack"

# Values from encrypted data bag
secrets = Chef::EncryptedDataBagItem.load('test-looper', 'server')
git_deploy_key = secrets['git_deploy_key']
test_looper_github_oauth_app_id = node[:test_looper_server][:github_oauth_app_id]
test_looper_github_app_client_secret = secrets['test_looper_github_app_client_secret']

ssl_private_key = secrets['ssl_private_key']
ssl_public_cert = secrets['ssl_public_cert']
ssl_chain = secrets['ssl_chain']


# Create a user to run the service
user service_account do
  action :create
  shell '/bin/bash'
end

# Create installation and supporting directories
[install_dir, ssh_dir, tasks_root_dir].each do |path|
  directory path do
    owner service_account
    group service_account
    action :create
  end
end

# Create the git ssh key (deployment key)
file deploy_key do
  content git_deploy_key
  owner service_account
  group service_account
  mode '0700'
end

# Copy SSL Certificate
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
deploy_revision src_dir do
  repo node[:test_looper_server][:git_repo]
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

template "/etc/init/test-looper-server.conf" do
  source "test-looper-server-upstart-conf.erb"
  variables({
      :service_account => service_account,
      :service_dir => service_dir,
      :git_ssh_wrapper => git_ssh_wrapper,
      :log_file => log_file,
      :stack_file => stack_file,
      :git_branch => git_branch,
      :test_looper_github_oauth_app_id => test_looper_github_oauth_app_id,
      :test_looper_github_app_client_secret => test_looper_github_app_client_secret,
      :tasks_root => tasks_root_dir,
      :http_port => http_port
  })
end


web_app "test-looper-proxy" do
  template "web_app.conf.erb"
  server_name dnsname
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
