#
# Cookbook Name:: test-looper
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'test-looper::apt-packages'
include_recipe 'test-looper::python-modules'

service_account = node[:test_looper][:service_account]
install_dir = node[:test_looper][:install_dir]

src_dir = "#{install_dir}/src"
ssh_dir = "#{install_dir}/.ssh"
deploy_key = "#{ssh_dir}/#{node[:test_looper][:github_deploy_key]}"
git_ssh_wrapper = "#{ssh_dir}/#{node[:test_looper][:git_ssh_wrapper]}"

git_branch = node[:test_looper][:git_branch]

log_file = "/var/log/test-looper.log"
stack_file = "#{log_file}.stack"

secrets = Chef::EncryptedDataBagItem.load('test-looper', 'server')
git_deploy_key = secrets['git_deploy_key']

user service_account do
  action :create
  shell '/bin/bash'
end

# Create installation and supporting directories
[install_dir, ssh_dir].each do |path|
  directory path do
    owner service_account
    group service_account
    action :create
  end
end

group "docker" do
  action :create
end

group "docker" do
  action :modify
  append true
  members service_account
end

service "docker.io" do
  action :restart
end

# Create the git ssh key (deployment key)
file deploy_key do
  content git_deploy_key
  owner service_account
  group service_account
  mode '0700'
end

# Create log files and set their ownership
[log_file, stack_file].each do |logfile|
  file logfile do
    owner service_account
    group service_account
  end
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

# Clone the repo into the installation directory
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
