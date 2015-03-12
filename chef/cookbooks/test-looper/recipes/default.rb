#
# Cookbook Name:: test-looper
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'test-looper::apt-packages'
include_recipe 'test-looper::python-modules'

tester_account = node[:test_looper][:tester_account]

user tester_account do
  action :create
  shell '/bin/bash'
end

group "docker" do
  action :create
end

group "docker" do
  action :modify
  append true
  members tester_account
end

service "docker.io" do
  action :restart
end

