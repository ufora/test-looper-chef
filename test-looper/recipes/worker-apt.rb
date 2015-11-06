apt_package 'git' do
  action :install
end
apt_package 'python-pip' do
  action :install
end
apt_package 'apt-transport-https' do
  action :install
end
# We configure docker to keep its data dir on the instance-store
# and that causes problems with the default filesystem (ext3).
# See: https://github.com/docker/docker/issues/4036
# We reformat the instance store using btrfs to work around the issue.
apt_package 'btrfs-tools' do
  action :install
end
