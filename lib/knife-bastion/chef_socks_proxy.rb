require_relative 'base_socks_proxy'
require 'socksify/http'

# Override `http_client` method in `Chef::HTTP` to return proxy object instead
# of normal client object.
Chef::HTTP.class_eval do
  alias_method :http_client_without_bastion, :http_client
  protected :http_client_without_bastion

  protected

  def http_client(*args)
    client = http_client_without_bastion(*args)
    options = {
      local_port: ::Chef::Config[:knife][:bastion_local_port],
      server_type: 'Chef',
    }
    KnifeBastion::ClientProxy.new(client, options)
  end
end


# Monkey-patch `configure_http_request` to configure SOCKS proxy
Chef::HTTP::HTTPRequest.class_eval do
  alias_method :configure_http_request_without_socks_proxy, :configure_http_request
  protected :configure_http_request_without_socks_proxy

  protected

  def configure_http_request(request_body = nil)
    req_path = path.to_s.dup
    req_path << "?#{query}" if query

    proxy_host = '127.0.0.1'
    proxy_port = @local_port

    http = Net::HTTP.SOCKSProxy(proxy_host, proxy_port).new(url.host, url.port)

    @http_request = case method.to_s.downcase
                  when 'get'
                    http.request(Net::HTTP::Get.new(req_path, headers))
                  when 'post'
                    http.request(Net::HTTP::Post.new(req_path, headers))
                  when 'put'
                    http.request(Net::HTTP::Put.new(req_path, headers))
                  when 'patch'
                    http.request(Net::HTTP::Patch.new(req_path, headers))
                  when 'delete'
                    http.request(Net::HTTP::Delete.new(req_path, headers))
                  when 'head'
                    http.request(Net::HTTP::Head.new(req_path, headers))
                  else
                    raise ArgumentError, "You must provide :GET, :PUT, :POST, :DELETE or :HEAD as the method"
                  end

    @http_request.body = request_body if request_body && @http_request.request_body_permitted?
    # Optionally handle HTTP Basic Authentication
    if url.user
      user = CGI.unescape(url.user)
      password = CGI.unescape(url.password) if url.password
      @http_request.basic_auth(user, password)
    end

    # Overwrite default UA
    @http_request[USER_AGENT] = self.class.user_agent
  end
end