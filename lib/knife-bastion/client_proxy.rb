require 'socket'
require 'timeout'
require 'highline'
require 'openssl'
require 'socksify/http'
require 'net/http'

module KnifeBastion
  # Simple class, that delegates all the calls to the base client
  # object. The latter is overwritten to first configure SOCKS proxy,
  # and if connection fails - show warning about the bastion setup.
  class ClientProxy < BasicObject
    NETWORK_ERRORS = [
      ::SocketError,
      ::Errno::ETIMEDOUT,
      ::Errno::ECONNRESET,
      ::Errno::ECONNREFUSED,
      ::Timeout::Error,
      ::OpenSSL::SSL::SSLError,
      defined?(::Berkshelf::ChefConnectionError) ? ::Berkshelf::ChefConnectionError : nil,
    ].compact.freeze

    # Initializes an instance of the generic client proxy which sends all the
    #   network traffic through the SOCKS proxy.
    # @param [Object] client the client object which communicates with the
    #   server over the network.
    # @param [Hash] options the configuration of the client proxy.
    # @option options [Integer]`NET` :local_port (4443) The local port of the SOCKS
    #   proxy.
    # @option options [Proc] :error_handler network errors handler.
    #   By default it prints out a message which explains that the error may
    #   occur becase the bastion proxy has not been started.
    def initialize(client, options = {})
      @client = client

      @local_port = options[:local_port] || 4443
      @chef_host = options[:chef_host]
      server_type = ::HighLine.color("#{options[:server_type]} ", [:bold, :cyan]) if options[:server_type]
      @network_errors_handler = options[:error_handler] || -> (e) {
        ::Kernel.puts
        ::Kernel.puts '-' * 80
        ::Kernel.puts ::HighLine.color("WARNING:", [:bold, :red]) + " Failed to contact #{server_type}server!"
        ::Kernel.puts "Error: #{e.class} - #{e.message}"
        ::Kernel.puts "You might need to start bastion connection with #{::HighLine.color("knife bastion start", [:bold, :magenta])} to access server."
        ::Kernel.puts '-' * 80
        ::Kernel.puts
        ::Kernel.raise
      }
      configure_socks_proxy
    end

    def configure_socks_proxy
      if @client.is_a?(::Net::HTTP)
        ::Kernel.puts " net http client detected"
        @client.socks_proxy_addr = '127.0.0.1'
        @client.socks_proxy_port = @local_port
      elsif @client.respond_to?(:http_client)
        ::Kernel.puts " chef http client detected"
        create_socks_proxy_http_client(@client, '127.0.0.1', @local_port)
      else
        ::Kernel.warn "Unsupported client type for SOCKS proxy configuration: #{@client.class}"
      end
    end

    def create_socks_proxy_http_client(existing_http_client, proxy_host, proxy_port)
      ::Kernel.puts "Creating SOCKS proxy HTTP client with parameters:"
      ::Kernel.puts "  Existing HTTP client address: #{existing_http_client.url.host}"
      ::Kernel.puts "  Existing HTTP client port: #{existing_http_client.url.port}"
      ::Kernel.puts "  Proxy host: #{proxy_host}"
      ::Kernel.puts "  Proxy port: #{proxy_port}"
    
      proxy_http_client = ::Net::HTTP.socks_proxy(proxy_host, proxy_port).new(@chef_host, existing_http_client.url.port, nil)
      proxy_http_client.open_timeout = existing_http_client.instance_variable_get(:@nethttp_opts)[:open_timeout]
      proxy_http_client.read_timeout = existing_http_client.instance_variable_get(:@nethttp_opts)[:read_timeout]
      proxy_http_client
    end
    

    def method_missing(method_name, *args, &block)
      begin
        response = @client.send(method_name, *args, &block)
      rescue *NETWORK_ERRORS => e
        @network_errors_handler.call(e)
      else
        ::Kernel.puts "HTTP Response: #{response.inspect}" if response.is_a?(::Net::HTTPResponse)
        response
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @client.respond_to?(method_name, include_private)
    end

  end
end
