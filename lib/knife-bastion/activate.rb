# Activate socks proxy for Knife and Berkshelf
if defined?(Chef::Application::Knife) || defined?(Berkshelf)
  require_relative 'chef_socks_proxy'
end
