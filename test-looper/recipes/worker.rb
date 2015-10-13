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
deploy_key = "#{ssh_dir}/#{node[:test_looper][:github_deploy_key]}"
git_ssh_wrapper = "#{ssh_dir}/#{node[:test_looper][:git_ssh_wrapper]}"

home_dir = "/home/#{service_account}"
test_src_dir = "#{home_dir}/src"
ccache_dir = "#{home_dir}/ccache"
build_cache_dir = "#{home_dir}/build_cache"
core_dump_dir = "#{home_dir}/core_dumps"
test_data_dir = "#{home_dir}/test_data"

git_branch = node[:test_looper][:git_branch]
expected_dependencies_version = node[:test_looper][:expected_dependencies_version]

log_file = "/var/log/test-looper.log"
stack_file = "#{log_file}.stack"

if node[:no_aws]
  secrets = Chef::EncryptedDataBagItem.load('test-looper', 'worker')
else
require 'aws-sdk'
  s3 = AWS::S3.new
  bucket = node[:test_looper][:data_bag_bucket]
  data_bag_key = node[:test_looper_worker][:data_bag_key]
  encrypted_data_bag = JSON.parse(s3.buckets[bucket].objects[data_bag_key].read)
  encrypted_data_bag_key = node[:test_looper][:encrypted_data_bag_key].gsub('\n', "\n").strip
  secrets = Chef::EncryptedDataBagItem.new(encrypted_data_bag, encrypted_data_bag_key)
end

git_deploy_key = secrets['git_deploy_key']

user service_account do
  supports :manage_home => true
  shell '/bin/bash'
  home home_dir
  action :create
end

include_recipe "test-looper::docker"

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
logrotate_app "test-looper" do
  path [log_file, stack_file]
  frequency "daily"
  rotate 7
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
deploy_revision src_dir do
  repo node[:test_looper][:git_repo]
  revision git_branch
  ssh_wrapper git_ssh_wrapper
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
  repo node[:test_looper][:git_repo]
  revision "master"
  ssh_wrapper git_ssh_wrapper
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
      :git_ssh_wrapper => git_ssh_wrapper,
      :log_file => log_file,
      :stack_file => stack_file,
      :expected_dependencies_version => expected_dependencies_version,
      :git_branch => git_branch,
      :config_file => config_file
  })
end
