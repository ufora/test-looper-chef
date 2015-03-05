apt_package 'git' do
  action :install
end

apt_package 'redis-server' do
  action :install
end
