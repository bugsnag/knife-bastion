require_relative 'bastion_base'

class Chef
  class Knife
    class BastionStatus < BastionBase
      include Chef::Mixin::ShellOut

      banner "knife bastion status (options)"
      category "bastion"

      def initialize_params
        super
      end

      def run
        initialize_params

        # Retrieve proxy process PID. Raises an error if something is wrong
        proxy_pid = tunnel_pid(@local_port)
        print_tunnel_info("Found an esablished tunnel:", pid: proxy_pid)
        
        response = check_tunnel_status('/policies')            
        if response.is_a?(Net::HTTPSuccess)
          ui.info ui.color("OK:  ", :green) + "The tunnel is up and running"
        else
          raise "Error: Tunnel is broken"
        end

      end
    end
  end
end
