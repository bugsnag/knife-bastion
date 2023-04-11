require_relative 'base_socks_proxy'

# Override `ridley_connection` method in `Berkshelf` to enable Socks proxy
# for the connection.
Berkshelf.module_eval do
  # class ChefConnectionError < StandardError; end
  # class BerkshelfError < StandardError; end
  class << self
    alias_method :ridley_connection_without_bastion, :ridley_connection

    def ridley_connection(options = {}, &block)
      proxy_host = '127.0.0.1'
      proxy_port = ::Chef::Config[:knife][:bastion_local_port]
      proxy = Net::HTTP::SOCKSProxy(proxy_host, proxy_port)

      ridley_connection_without_bastion(options) do |builder|
        builder.options[:proxy] = {
          host: proxy_host,
          port: proxy_port
        }
      end
    end
  end
end