# assumes that the docker.io apt package has been installed
# see worker-apt.rb for an example

service_account = node[:test_looper][:service_account]
graph_dir = node[:test_looper][:docker][:graph_dir]
tmp_dir = node[:test_looper][:docker][:tmp_dir]

[graph_dir, tmp_dir].each do |path|
    directory path do
        action :create
        recursive true
    end
end

template "/etc/default/docker.io" do
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

execute "restart docker.io" do
  action :run
end
