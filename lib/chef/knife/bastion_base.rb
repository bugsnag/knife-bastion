require 'chef/knife'

class Chef
  class Knife
    class BastionBase < Knife
      include Chef::Mixin::ShellOut

      def initialize_params
        @bastion_user    = Chef::Config[:knife][:bastion_user] || ENV['CHEF_USER'] || ENV['USER']
        @bastion_host    = Chef::Config[:knife][:bastion_host]
        @bastion_network = Chef::Config[:knife][:bastion_network]
        @bastion_port    = Chef::Config[:knife][:bastion_port] || 22
        @chef_host       = URI.parse(Chef::Config[:chef_server_url]).host
        @local_port      = Chef::Config[:knife][:bastion_local_port] || 4443
      end

      def tunnel_pid(local_port, raise_on_closed_port = true)
        # Check if local port is open, get proxy process PID
        pid_result = shell_out("lsof -nPt -i4TCP:#{local_port} -sTCP:LISTEN")
        unless pid_result.status.success?
          if raise_on_closed_port
            ui.fatal "Tunnel is not open on port #{local_port}"
            abort
          end
          return nil
        end
        proxy_pid = pid_result.stdout.chomp

        # Verify tunnel destination
        bastion_ip_addr = Socket.getaddrinfo(@bastion_host, nil, :INET, :STREAM, Socket::IPPROTO_TCP).first[3]
        dest_result = shell_out("lsof -an -p #{proxy_pid} -i4@#{bastion_ip_addr}:#{@bastion_port}")
        unless dest_result.status.success?
          ui.fatal "There is a process with PID #{proxy_pid} listening on port #{local_port}, but it does not look like a tunnel"
          abort
        end

        proxy_pid
      end

      def print_tunnel_info(header, timeout: nil, pid: nil)
        ui.info <<-INFO
#{header}
  * Bastion host: #{ui.color "#{@bastion_user}@#{@bastion_host}", :bold, :white}
  *    Chef host: #{ui.color @chef_host, :bold, :white}
  *   Local port: #{ui.color @local_port.to_s, :bold, :white}
        INFO
        if timeout
          ui.info <<-INFO
  *      Timeout: #{ui.color timeout.to_s, :bold, :white} seconds
          INFO
        end
        if pid
          ui.info <<-INFO
  *    Proxy PID: #{ui.color pid.to_s, :bold, :white}
          INFO
        end
      end

      def run
        initialize_params

        # Retrieve proxy process PID. Raises an error if something is wrong
        proxy_pid = tunnel_pid(@local_port)
        print_tunnel_info("Found an esablished tunnel:", pid: proxy_pid)

        # This line will raise an exception if tunnel is broken
        response = check_tunnel_status('/policies')            
        if response.is_a?(Net::HTTPSuccess)
          ui.info ui.color("OK:  ", :green) + "The tunnel is up and running"
        else
          raise "Error: Tunnel is broken"
        end
      end

      def check_tunnel_status(path)
        require 'socksify/http'

        uri = URI.parse("https://#{@chef_host}#{path}")
        resp = nil
      
        Net::HTTP.socks_proxy('127.0.0.1', @local_port).start(uri.host, uri.port, use_ssl: (uri.scheme == 'https')) do |http|
          req = Net::HTTP::Get.new(uri.request_uri)
          resp = http.request(req)
        end
        resp
      end  
    end
  end
end
