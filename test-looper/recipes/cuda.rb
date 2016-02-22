# Install CUDA
remote_file '/tmp/cuda-repo-ubuntu1404_7.5-18_amd64.deb' do
  source 'http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/cuda-repo-ubuntu1404_7.5-18_amd64.deb'
end
dpkg_package 'cuda-repo-ubuntu1404_7.5-18_amd64' do
  action :install
  source '/tmp/cuda-repo-ubuntu1404_7.5-18_amd64.deb'
  notifies :run, 'execute[apt-get update]', :immediately
end
apt_package 'cuda-nvrtc-7-5' do
  action :install
  options '--no-install-recommends --force-yes'
end
apt_package 'cuda-cudart-7-5' do
  action :install
  options '--no-install-recommends --force-yes'
end
apt_package 'cuda-drivers' do
  action :install
  options '--no-install-recommends --force-yes'
end
apt_package 'cuda-core-7-5' do
  action :install
  options '--no-install-recommends --force-yes'
end
apt_package 'cuda-driver-dev-7-5' do
  action :install
  options '--no-install-recommends --force-yes'
end


# Install nvidia-docker

# Using wget instead of "remote_file" due to a bug in chef 11.10 which is what is used by OpsWorks.
# They now make chef 12 available but there is no upgrade path to it and the stack would need to be
# recreated.
#remote_file '/tmp/nvidia-docker_1.0.0.beta-1_amd64.deb' do
  #source 'https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.0-beta/nvidia-docker_1.0.0.beta-1_amd64.deb'
#end

bash 'download nvidia-docker' do
    cwd '/tmp'
    code <<-EOH
    wget https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.0-beta/nvidia-docker_1.0.0.beta-1_amd64.deb
    EOH
end
unless node[:no_aws]
    dpkg_package 'nvidia-docker_1.0.0.beta-1_amd64' do
      action :install
      source '/tmp/nvidia-docker_1.0.0.beta-1_amd64.deb'
    end
end
