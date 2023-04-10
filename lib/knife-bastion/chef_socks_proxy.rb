require_relative 'base_socks_proxy'
require 'socksify/http'

# Override `build_http_client` method in `Chef::HTTP` to return proxy object instead
# of normal client object.
Chef::HTTP::BasicClient.class_eval do
  alias_method :build_http_client_without_bastion, :build_http_client
  protected :build_http_client_without_bastion

  protected

  def build_http_client
    # Configure the socks_proxy with your SOCKS proxy settings
    proxy_host = '127.0.0.1'
    proxy_port = ::Chef::Config[:knife][:bastion_local_port]
    chef_host = URI.parse(Chef::Config[:chef_server_url]).host

    # Note: the last nil in the new below forces Net::HTTP to ignore the
    # no_proxy environment variable. This is a workaround for limitations
    # in Net::HTTP use of the no_proxy environment variable. We internally
    # match no_proxy with a fuzzy matcher, rather than letting Net::HTTP
    # do it.
    http_client = Net::HTTP.socks_proxy(proxy_host, proxy_port).new(chef_host, port, nil)
    http_client.proxy_port = nil if http_client.proxy_address.nil?
  
    if url.scheme == 'https'
      configure_ssl(http_client)
    end
  
    opts = nethttp_opts.dup
    opts["read_timeout"] ||= config[:rest_timeout]
    opts["open_timeout"] ||= config[:rest_timeout]
  
    opts.each do |key, value|
      http_client.send(:"#{key}=", value)
    end

    if keepalives
      http_client.start
    else
      http_client
    end
    
    http_client
  end
end