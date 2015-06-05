#
# Cookbook Name:: test-looper-server
# Recipe:: setup
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#
# Creates user accounts, directories, ssh keys, and other
# fairly static resources on the machine


service_account = node[:test_looper_server][:service_account]
home_dir = "/home/#{service_account}"

install_dir = node[:test_looper_server][:install_dir]
ssh_dir = "#{install_dir}/.ssh"
tasks_root_dir = "#{install_dir}/tasks"
deploy_dir = "#{install_dir}/deploy-src"

#config_file = "#{install_dir}/test-looper-server.conf"
#src_dir = "#{install_dir}/src"
#service_dir = "#{src_dir}/current"
#deploy_key = "#{ssh_dir}/#{node[:test_looper_server][:github_deploy_key]}"
#git_ssh_wrapper = "#{ssh_dir}/#{node[:test_looper_server][:git_ssh_wrapper]}"

#ssl_dir = node[:test_looper_server][:ssl_dir]
#cert_name = node[:test_looper_server][:ssl_cert_prefix]
#public_cert_file = "#{ssl_dir}/#{cert_name}.crt"
#private_key_file = "#{ssl_dir}/#{cert_name}.key"
#cert_chain_file = "#{ssl_dir}/#{cert_name}.ca"

s3 = AWS::S3.new
bucket = node[:test_looper_server][:data_bag_bucket]
data_bag_key = node[:test_looper_server][:data_bag_key]
encrypted_data_bag = s3.buckets[bucket].objects[data_bag_key].read
encrypted_data_bag_key = node[:test_looper_server][:encrypted_data_bag_key]
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
