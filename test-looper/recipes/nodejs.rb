include_recipe "nodejs::npm"

bash 'node_symlink' do
  code 'ln -s /usr/bin/nodejs /usr/bin/node'
  creates '/usr/bin/node'
end

nodejs_npm 'coffee-script' do
  version "1.4.0"
end
nodejs_npm 'mocha'
nodejs_npm 'grunt-cli'
nodejs_npm 'bower'
nodejs_npm 'forever' do
  version "0.11.1"
end
