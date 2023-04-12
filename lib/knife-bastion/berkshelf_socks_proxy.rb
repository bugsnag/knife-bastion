require_relative 'base_socks_proxy'

# Override `ridley_connection` method in `Berkshelf` to enable Socks proxy
# for the connection.
Berkshelf.module_eval do
  # class ChefConnectionError < StandardError; end
  # class BerkshelfError < StandardError; end
  # ridley_compat = RidleyCompat

  class << self
    alias_method :ridley_connection_without_bastion, :ridley_connection

    def ridley_connection(options = {}, &block)
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
    proxy_host = opts.delete(:proxy_host)
    proxy_port = opts.delete(:proxy_port)
    puts "Initializing RidleyCompatAPI with options: #{opts.inspect}"
    initialize_original(**opts)

    if proxy_host && proxy_port
      self.http_client = Chef::HTTP.new(self, builder: Chef::HTTP::Builder.new(self, middleware))
      self.http_client.builder.adapter = Net::HTTP.SOCKSProxy(proxy_host, proxy_port)
      puts "Added the http_client: #{http_client.inspect}"
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


