include_recipe 'python'
include_recipe 'python::pip'
pymodules = ['boto', 'requests', 'simplejson',
  'twisted', 'bcrypt', 'docopt', 'markdown', 'nose', 'numpy', 'pyOpenSSL', 'pyodbc', 'redis', 'service_identity', 'zope.interface',
  'paramiko']

pymodules.each do |pymodule|
  python_pip pymodule do
    action :install
    options "--allow-unverified pyodbc"
  end
end
