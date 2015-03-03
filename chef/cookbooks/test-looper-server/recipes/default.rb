#
# Cookbook Name:: test-looper-server
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

credentials = Chef::EncryptedDataBagItem.load('test_looper', 'server')
install_dir = node[:test_looper_server][:install_dir]
git_branch = node[:test_looper_server][:git_branch]
deploy_key = node[:test_looper_server][:github_deploy_key]
service_account = node[:test_looper_server][:service_account]

apt_package 'git' do
  action :install
end

user service_account do
  action :create
  shell '/bin/bash'
end

[install_dir, "#{install_dir}/.ssh"].each do |path|
  directory path do
    owner service_account
    group service_account
    action :create
  end
end

template "#{install_dir}/wrap-ssh4git.sh" do
  source 'git-ssh-wrapper.erb'
  owner service_account
  group service_account
  mode '0700'
  variables({
      :install_dir => install_dir,
      :deploy_key => deploy_key
  })
end

file "#{install_dir}/#{deploy_key}" do
  content credentials['git_deploy_key']
  owner service_account
  group service_account
  mode '0700'
end

template "/etc/init/test-looper-server.conf" do
  source "test-looper-server-upstart-conf.erb"
  variables({
      :service_account => service_account,
      :install_dir => install_dir,
      :src_dir => "#{install_dir}/src",
      :git_branch => git_branch,
      :github_login => node[:test_looper_server][:github_login],
      :github_token => credentials['github_token'],
      :test_looper_github_auth_secret => credentials['test_looper_github_auth_secret'],
      :test_looper_github_app_client_secret => credentials['test_looper_github_app_client_secret']
  })
end

deploy_revision "#{install_dir}/src" do
  repo node[:test_looper_server][:git_repo]
  revision git_branch
  ssh_wrapper "#{install_dir}/wrap-ssh4git.sh"
  user service_account
  group service_account
  action :deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end
