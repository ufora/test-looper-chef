#
# Cookbook Name:: test-looper
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.


service_account = node[:test_looper][:service_account]
install_dir = node[:test_looper_worker][:install_dir]
config_file = "#{install_dir}/#{node[:test_looper_worker][:config_file]}"

src_dir = "#{install_dir}/src"
ssh_dir = "#{install_dir}/.ssh"
deploy_key_target = "#{ssh_dir}/#{node[:test_looper][:github_deploy_key_target]}"
deploy_key_looper = "#{ssh_dir}/#{node[:test_looper][:github_deploy_key_looper]}"
git_ssh_wrapper_target_repo = "#{ssh_dir}/#{node[:test_looper][:git_ssh_wrapper_target_repo]}"
git_ssh_wrapper_looper_repo = "#{ssh_dir}/#{node[:test_looper][:git_ssh_wrapper_looper_repo]}"

home_dir = "/home/#{service_account}"
test_src_dir = "#{home_dir}/src"
ccache_dir = "#{home_dir}/ccache"
build_cache_dir = "#{home_dir}/build_cache"
core_dump_dir = node[:test_looper_worker][:core_dump_dir]
test_data_dir = "#{home_dir}/test_data"

looper_branch = node[:test_looper][:looper_branch]

log_file = "/var/log/test-looper.log"
stack_file = "#{log_file}.stack"

if node[:no_aws]
  secrets = Chef::EncryptedDataBagItem.load('test-looper', 'worker')
else
require 'aws-sdk'
  s3 = AWS::S3.new
  env = node[:test_looper][:environment] # prod, dev, etc.
  bucket = node[:test_looper][:data_bag_bucket]
  data_bag_key = node[:test_looper_worker][:data_bag_key]
  encrypted_data_bag = JSON.parse(s3.buckets[bucket].objects["#{env}/#{data_bag_key}"].read)
  encrypted_data_bag_key = node[:test_looper][:encrypted_data_bag_key].gsub('\n', "\n").strip
  secrets = Chef::EncryptedDataBagItem.new(encrypted_data_bag, encrypted_data_bag_key)
end

git_deploy_key_target = secrets['git_deploy_key']
git_deploy_key_looper = secrets['test_looper_repo_deploy_key']

user service_account do
  supports :manage_home => true
  shell '/bin/bash'
  home home_dir
  action :create
end

include_recipe 'apt'
include_recipe "test-looper::docker"
include_recipe "test-looper::cuda"

directories = [home_dir, install_dir, src_dir, ssh_dir,
               test_src_dir, ccache_dir, build_cache_dir, core_dump_dir, test_data_dir]

# Create installation and supporting directories
directories.each do |path|
  directory path do
    owner service_account
    group service_account
    action :create
  end
end



docker_hub = secrets['docker_hub']
file "#{home_dir}/.dockercfg" do
  content %Q!{"#{docker_hub['hostname']}":{"auth":"#{docker_hub['auth']}","email":"#{docker_hub['email']}"}}!
  owner service_account
  group service_account
end

file "/proc/sys/kernel/core_pattern" do
  atomic_update false # without this, writing to /proc fails in ec2
  content "#{core_dump_dir}/core.%p"

  # don't write to /proc in docker (because it won't let us)
  not_if "mount | grep 'proc on /proc/sys type proc (ro,'"
end


# Create the git ssh key (deployment key) for the target repo
file deploy_key_target do
  content git_deploy_key_target
  owner service_account
  group service_account
  mode '0700'
end
# Create the git ssh key (deployment key) for the looper repo
file deploy_key_looper do
  content git_deploy_key_looper
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
logrotate_app "test-looper" do
  path [log_file, stack_file]
  frequency "daily"
  rotate 7
end

# Create the git ssh wrappers that uses our deployment keys
template git_ssh_wrapper_looper_repo do
  source 'git-ssh-wrapper.erb'
  owner service_account
  group service_account
  mode '0700'
  variables({
      :deploy_key => deploy_key_looper
  })
end
template git_ssh_wrapper_target_repo do
  source 'git-ssh-wrapper.erb'
  owner service_account
  group service_account
  mode '0700'
  variables({
      :deploy_key => deploy_key_target
  })
end

# Clone the repo into the installation directory
# this is for the test-looper branch!
deploy_revision src_dir do
  repo node[:test_looper][:looper_repo]
  revision looper_branch
  ssh_wrapper git_ssh_wrapper_looper_repo
  user service_account
  group service_account
  action :force_deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end

# clone the repo for the builder account
deploy_revision test_src_dir do
  repo node[:test_looper][:target_repo]
  revision "master"
  ssh_wrapper git_ssh_wrapper_target_repo
  user service_account
  group service_account
  action :force_deploy

  symlink_before_migrate.clear
  create_dirs_before_symlink.clear
  purge_before_symlink.clear
  symlinks.clear
end

template config_file do
  source "worker-conf.erb"
  owner service_account
  group service_account
  variables({
    :worker_repo_path => "#{test_src_dir}/current",
    :worker_core_dump_dir => core_dump_dir,
    :worker_test_data_dir => test_data_dir,
    :worker_ccache_dir => ccache_dir,
    :worker_build_cache_dir => build_cache_dir,
    :ec2_test_result_bucket => node[:test_looper][:test_results_bucket],
    :ec2_builds_bucket => node[:test_looper][:builds_bucket]
    })
end

template "/etc/init/test-looper.conf" do
  source "worker-init.erb"
  variables({
      :service_account => service_account,
      :src_dir => src_dir,
      :git_ssh_wrapper => git_ssh_wrapper_looper_repo,
      :git_target_ssh_wrapper => git_ssh_wrapper_target_repo,
      :log_file => log_file,
      :stack_file => stack_file,
      :looper_branch => looper_branch,
      :config_file => config_file
  })
end
