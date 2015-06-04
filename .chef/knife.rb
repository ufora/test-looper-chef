# See https://docs.chef.io/config_rb_knife.html for more information on knife configuration options

#validation_client_name   "ufora-validator"
#validation_key           "#{current_dir}/ufora-validator.pem"

current_dir = File.dirname(__FILE__)
user_email  = `git config --get user.email`
home_dir    = ENV['HOME'] || ENV['HOMEDRIVE']
chef_dir    = "#{home_dir}/chef-repo"
org         = ENV['chef_org'] || 'ufora'

knife_override = "#{chef_dir}/.chef/knife_override.rb"

chef_server_url          "https://api.opscode.com/organizations/#{org}"
log_level                :info
log_location             STDOUT

node_name                ENV['USER']
#client_key               "#{chef_dir}/.chef/#{node_name}.pem"
cache_type               'BasicFile'
cache_options( :path => "#{chef_dir}/.chef/checksums" )

cookbook_path            ["#{current_dir}/../cookbooks"]
cookbook_copyright       "Ufora, Inc."
cookbook_license         "none"
cookbook_email           "#{user_email}"

#http_proxy               "http://webproxy.example.com:80"
#https_proxy              "http://webproxy.example.com:80"
#no_proxy                 "localhost, 10.*, *.example.com, *.dev.example.com"

# Allow overriding values in this knife.rb
if File.exist?(knife_override)
  ::Chef::Log.info("Loading user-specific configuration from #{knife_override}") if defined?(::Chef)
    instance_eval(IO.read(knife_override), knife_override, 1)
end
