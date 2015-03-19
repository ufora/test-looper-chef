include_recipe 'python'
include_recipe 'python::pip'
pymodules = ['boto', 'requests', 'simplejson']

pymodules.each do |pymodule|
  python_pip pymodule do
    action :install
  end
end
