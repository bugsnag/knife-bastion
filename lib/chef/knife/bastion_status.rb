require_relative 'bastion_base'

class Chef
  class Knife
    class BastionStatus < BastionBase
      include Chef::Mixin::ShellOut

      banner "knife bastion status (options)"
      category "bastion"

      def run
        initialize_params

        # Retrieve proxy process PID. Raises an error if something is wrong
        proxy_pid = tunnel_pid(@local_port)
        print_tunnel_info("Found an esablished tunnel:", pid: proxy_pid)

        puts get_content_via_socks('localhost', @local_port, @chef_host, '/policies')
        # This line will raise an exception if tunnel is broken
        # rest.get_rest("/policies")
        ui.info ui.color("OK:  ", :green) + "The tunnel is up and running"
      end
    end
  end
end
