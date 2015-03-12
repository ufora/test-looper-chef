#
# Cookbook Name:: test-looper
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'test-looper::apt-packages'
include_recipe 'test-looper::python-modules'

service_account = node[:test_looper][:service_account]
install_dir = node[:test_looper][:install_dir]

ssh_dir = "#{install_dir}/.ssh"
deploy_key = "#{ssh_dir}/#{node[:test_looper][:github_deploy_key]}"

secrets = Chef::EncryptedDataBagItem.load('test-looper', 'server')
git_deploy_key = secrets['git_deploy_key']

user service_account do
  action :create
  shell '/bin/bash'
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

# Create the git ssh key (deployment key)
file deploy_key do
  content git_deploy_key
  owner service_account
  group service_account
  mode '0700'
end
