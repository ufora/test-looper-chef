#
# Cookbook Name:: test-looper-server
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'apache2'
include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_proxy'
include_recipe 'apache2::mod_proxy_http'

include_recipe 'test-looper-server::apt-packages'
include_recipe 'test-looper-server::python-modules'

credentials = Chef::EncryptedDataBagItem.load('test-looper', 'server')
service_account = node[:test_looper_server][:service_account]
install_dir = node[:test_looper_server][:install_dir]
src_dir = "#{install_dir}/src"
service_dir = "#{src_dir}/current"
ssh_dir = "#{install_dir}/.ssh"
deploy_key = "#{ssh_dir}/#{node[:test_looper_server][:github_deploy_key]}"
git_ssh_wrapper = "#{ssh_dir}/#{node[:test_looper_server][:git_ssh_wrapper]}"
tasks_root_dir = "#{install_dir}/tasks"

git_branch = node[:test_looper_server][:git_branch]

log_file = "/var/log/test-looper-server.log"
stack_file = "#{log_file}.stack"


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
  content credentials['git_deploy_key']
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

# Clone the repo insto the installation directory
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
      :github_login => node[:test_looper_server][:github_login],
      :github_token => credentials['github_token'],
      :test_looper_github_auth_secret => credentials['test_looper_github_auth_secret'],
      :test_looper_github_app_client_secret => credentials['test_looper_github_app_client_secret'],
      :tasks_root => tasks_root_dir
  })
end

web_app "test-looper-proxy" do
  template "web_app.conf.erb"

end
