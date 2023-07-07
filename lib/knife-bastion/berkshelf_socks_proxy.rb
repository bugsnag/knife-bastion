require_relative 'base_socks_proxy'

# Override `ridley_connection` method in `Berkshelf` to enable Socks proxy
# for the connection.
Berkshelf.module_eval do
  class << self
    alias_method :ridley_connection_without_bastion, :ridley_connection

    def ridley_connection(options = {}, &block)
        options[:proxy_host] = '127.0.0.1'
        options[:proxy_port] = ::Chef::Config[:knife][:bastion_local_port]
        puts "ridley_connection called #{options.inspect}"
        options[:proxy_host] = '127.0.0.1'
        options[:proxy_port] = ::Chef::Config[:knife][:bastion_local_port]
        puts "ridley_connection called #{options.inspect}"

        ridley_connection_without_bastion(options, &block)
    end
  end
end

Berkshelf::RidleyCompatAPI.module_eval do
  alias_method :initialize_original, :initialize

  def initialize(**opts)
    if opts[:proxy_host] && opts[:proxy_port]
      proxy_host = opts[:proxy_host]
      proxy_port = opts[:proxy_port]
      puts "~~~~~Initializing RidleyCompatAPI with options: #{opts.inspect}"
      http_client = Net::HTTP::SOCKSProxy(proxy_host, proxy_port)
      http_client.proxy_port = nil if http_client.proxy_address.nil?
      puts "~~~~~Added the http_client: #{http_client.inspect}"
      super(http_client, **opts)
    else
      initialize_original(opts)
    end
  end
end

Berkshelf::RidleyCompatAPI::ClassMethods.module_eval do
  def new_client(**opts)
    client = new(**opts)
    puts "Created a new client: #{client.inspect}"
    if block_given?
      puts "Executing block with the client..."
      yield client
      puts "Block execution finished."
    else
      puts "No block provided."
    end
    # ensure
    # FIXME: does Chef::HTTP support close anywhere?  this will just leak open fds
  end
end



Chef::HTTP.module_eval do

    def http_client
      return @http_client if @http_client

      proxy_host = '127.0.0.1'
      proxy_port = 4443

      @http_client = Net::HTTP.SOCKSProxy(proxy_host, proxy_port).new(@url.host, @url.port, nil)
      @http_client.use_ssl = @url.scheme == "https"
      @http_client.verify_mode = OpenSSL::SSL::VERIFY_NONE if @config[:ssl_verify_mode] == :verify_none
      @http_client.open_timeout = @config[:open_timeout] if @config[:open_timeout]
      @http_client.read_timeout = @config[:read_timeout] if @config[:read_timeout]
      @http_client.start
      ::Kernel.puts "~~~~http_client called~~~~ proxy added ~~~~"
      @http_client
    end

    def request(method, url, headers = {}, data = false)
      ::Kernel.puts "~~~~HTTP request dump~~~~"
      puts "Chef::HTTP Request (#{method}): #{url}"
      puts "Headers: #{headers.inspect}"
      puts "Data: #{data.inspect}" if data
      # Call the original request method
      super(method, url, headers, data)
    end
end

