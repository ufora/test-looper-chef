#
# Cookbook Name:: test-looper
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'apt'

include_recipe 'test-looper::apt-packages'
include_recipe 'test-looper::python-modules'

service_account = node[:test_looper][:service_account]
install_dir = node[:test_looper][:install_dir]

test_looper_src_dir = "#{install_dir}/src"
ssh_dir = "#{install_dir}/.ssh"
deploy_key = "#{ssh_dir}/#{node[:test_looper][:github_deploy_key]}"
git_ssh_wrapper = "#{ssh_dir}/#{node[:test_looper][:git_ssh_wrapper]}"

home_dir = "/home/#{service_account}"
builder_projects_dir = "#{home_dir}/src"
builder_src_dir = "#{builder_projects_dir}/current"

core_path = "/mnt/cores"
cumulus_data_path = '/mnt/ufora'

test_looper_git_branch = node[:test_looper][:test_looper_git_branch]

log_file = "/var/log/test-looper.log"
stack_file = "#{log_file}.stack"

secrets = Chef::EncryptedDataBagItem.load('test-looper', 'server')
git_deploy_key = secrets['git_deploy_key']

user service_account do
  supports :manage_home => true
  shell '/bin/bash'
  home home_dir
  action :create
end

directories = [home_dir, install_dir, test_looper_src_dir, ssh_dir, builder_projects_dir, core_path, cumulus_data_path]

# Create installation and supporting directories
directories.each do |path|
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

file "/proc/sys/kernel/core_pattern" do
  atomic_update false # without this, writing to /proc fails in ec2
  content "#{core_path}/core.%p"

  # don't write to /proc in docker (because it won't let us)
  not_if "mount | grep 'proc on /proc/sys type proc (ro,'"
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
# this is for the test-looper branch!
deploy_revision test_looper_src_dir do
  repo node[:test_looper][:git_repo]
  revision test_looper_git_branch
  ssh_wrapper git_ssh_wrapper
  user service_account
  group service_account
  action :deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end

# clone the repo for the builder account
deploy_revision builder_projects_dir do
  repo node[:test_looper][:git_repo]
  revision "master"
  ssh_wrapper git_ssh_wrapper
  user service_account
  group service_account
  action :deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end

template "/etc/init/test-looper.conf" do
  source "test-looper-upstart-conf.erb"
  variables({
      :service_account => service_account,
      :test_looper_src_dir => test_looper_src_dir,
      :log_file => log_file,
      :stack_file => stack_file,
      :test_looper_git_branch => test_looper_git_branch,
      :github_login => node[:test_looper][:github_login]
  })
end
