# Update kernel
kernel_release = node['kernel']['release']
apt_package "linux-headers-#{kernel_release}" do
    action :install
    options '--force-yes'
end
apt_package "linux-image-#{kernel_release}" do
    action :install
    options '--force-yes'
end
apt_package "linux-image-extra-#{kernel_release}" do
    action :install
    options '--force-yes'
end


# Install CUDA
remote_file '/tmp/cuda-repo-ubuntu1604_8.0.44-1_amd64.deb' do
  source 'http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_8.0.44-1_amd64.deb'
end
dpkg_package 'cuda-repo-ubuntu1604_8.0.44-1_amd64' do
  action :install
  source '/tmp/cuda-repo-ubuntu1604_8.0.44-1_amd64.deb'
  notifies :run, 'execute[apt-get update]', :immediately
end
package 'cuda-core-8-0' do
  action :install
  options '--no-install-recommends --force-yes'
end
package 'cuda-cudart-8-0' do
  action :install
  options '--no-install-recommends --force-yes'
end
package 'cuda-cudart-dev-8-0' do
  action :install
  options '--no-install-recommends --force-yes'
end
package 'cuda-driver-dev-8-0' do
  action :install
  options '--no-install-recommends --force-yes'
end
package 'cuda-drivers' do
  action :install
  options '--no-install-recommends --force-yes'
end
package 'cuda-nvrtc-8-0' do
  action :install
  options '--no-install-recommends --force-yes'
end
package 'libcuda1-367' do
  action :install
  options '--no-install-recommends --force-yes'
end


# Install nvidia-docker

# Using wget instead of "remote_file" due to a bug in chef 11.10 which is what is used by OpsWorks.
# They now make chef 12 available but there is no upgrade path to it and the stack would need to be
# recreated.
#remote_file '/tmp/nvidia-docker_1.0.0.rc.3-1_amd64.deb' do
  #source 'https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.0-rc.3/nvidia-docker_1.0.0.rc.3-1_amd64.deb'
#end

execute 'download-nvidia-docker' do
    cwd '/tmp'
    command '/usr/bin/wget -nv https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.0-rc.3/nvidia-docker_1.0.0.rc.3-1_amd64.deb'
end
unless node[:no_aws]
    dpkg_package 'nvidia-docker_1.0.0.rc.3-1_amd64' do
      action :install
      source '/tmp/nvidia-docker_1.0.0.rc.3-1_amd64.deb'
    end
end
