include_recipe 'python'
include_recipe 'python::pip'
pymodules = ['cython', 'boto', 'requests', 'simplejson',
             'selenium']

pymodules.each do |pymodule|
  python_pip pymodule do
    action :install
  end
end
