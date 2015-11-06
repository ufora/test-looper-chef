# assumes that the docker apt package has been installed
# see worker-apt.rb for an example

apt_repository 'docker' do
  uri 'https://apt.dockerproject.org/repo'
  components ['main']
  distribution 'ubuntu-trusty'
  key '58118E89F3A912897C070ADBF76221572C52609D'
  keyserver 'hkp://pgp.mit.edu:80'
  action :add
end

apt_package 'docker-engine' do
  action :install
end

service_account = node[:test_looper][:service_account]
graph_dir = node[:test_looper][:docker][:graph_dir]
tmp_dir = node[:test_looper][:docker][:tmp_dir]

[graph_dir, tmp_dir].each do |path|
    directory path do
        action :create
        recursive true
    end
end

template "/etc/default/docker" do
    source "docker-conf.erb"
    variables({
        :docker_graph_dir => graph_dir,
        :docker_tmp_dir => tmp_dir
    })
end

group "docker" do
  action :create
end

group "docker" do
  action :modify
  append true
  members service_account
end

ruby_block 'disable docker auto start' do
    block do
        fe = Chef::Util::FileEdit.new('/etc/init/docker.conf')
        fe.search_file_delete_line(/^start on/)
        fe.write_file
    end
    action :run
end

execute "restart docker" do
  action :run
end
