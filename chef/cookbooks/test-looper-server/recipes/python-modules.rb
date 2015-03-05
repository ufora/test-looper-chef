include_recipe 'python'
include_recipe 'python::pip'
pymodules = ['pygithub3', 'simplejson', 'redis', 'boto', 'pytz', 'cherrypy', 'python-dateutil',
             'numpy', 'markdown', 'fabric', 'requests']

pymodules.each do |pymodule|
  python_pip pymodule do
    action :install
  end
end
