#
# Cookbook Name:: test-looper
# Recipe:: server-externals
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#
# Installs external dependencies: OS packages, Python modules, etc.

include_recipe 'apt'

include_recipe 'apache2'
include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_proxy'
include_recipe 'apache2::mod_proxy_http'

include_recipe 'test-looper::server-apt'
include_recipe 'test-looper::server-python'

