#
# Cookbook Name:: test-looper
# Recipe:: worker-externals
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#
# Installs external dependencies: OS packages, Python modules, etc.

include_recipe 'apt'
include_recipe 'test-looper::worker-apt'
include_recipe 'test-looper::worker-python'
include_recipe 'ntp'
include_recipe 'logrotate'
