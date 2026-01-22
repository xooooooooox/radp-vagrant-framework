# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM network settings
    # Reference: https://developer.hashicorp.com/vagrant/docs/networking
    module Network
      class << self
        def configure(vm_config, guest, env: nil)
          # Hostname is now at guest level
          configure_hostname(vm_config, guest, env)

          network = guest['network']
          return unless network

          configure_private_network(vm_config, network['private-network'])
          configure_public_network(vm_config, network['public-network'])
          configure_forwarded_ports(vm_config, network['forwarded-ports'])
        end

        private

        def configure_hostname(vm_config, guest, env)
          hostname = guest['hostname']

          # Convention: if hostname is empty, default to <guest-id>.<cluster-name>.<env>
          if hostname.nil? || hostname.empty?
            cluster_name = guest['_cluster_name'] || 'cluster'
            resolved_env = env || 'local'
            hostname = "#{guest['id']}.#{cluster_name}.#{resolved_env}"
          end

          vm_config.vm.hostname = hostname
        end

        def configure_private_network(vm_config, config)
          return unless config && config['enabled']

          base_options = {}
          base_options[:auto_config] = config['auto-config'] if config.key?('auto-config')

          if config['type'] == 'dhcp'
            base_options[:type] = 'dhcp'
            vm_config.vm.network 'private_network', **base_options
          else
            # Support single IP (string) or multiple IPs (array)
            ips = Array(config['ip'])
            ips.each do |ip|
              options = base_options.dup
              options[:ip] = ip
              options[:netmask] = config['netmask'] if config['netmask']
              vm_config.vm.network 'private_network', **options
            end
          end
        end

        def configure_public_network(vm_config, config)
          return unless config && config['enabled']

          base_options = {}
          base_options[:bridge] = config['bridge'] if config['bridge']
          base_options[:auto_config] = config['auto-config'] if config.key?('auto-config')
          base_options[:use_dhcp_assigned_default_route] = config['use-dhcp-assigned-default-route'] if config.key?('use-dhcp-assigned-default-route')

          if config['type'] == 'dhcp'
            base_options[:type] = 'dhcp'
            vm_config.vm.network 'public_network', **base_options
          else
            # Support single IP (string) or multiple IPs (array)
            ips = Array(config['ip'])
            ips.each do |ip|
              options = base_options.dup
              options[:ip] = ip
              options[:netmask] = config['netmask'] if config['netmask']
              vm_config.vm.network 'public_network', **options
            end
          end
        end

        def configure_forwarded_ports(vm_config, ports)
          return unless ports

          ports.each do |port|
            next unless port['enabled']

            options = {
              guest: port['guest'],
              host: port['host']
            }
            options[:protocol] = port['protocol'] if port['protocol']
            options[:id] = port['id'] if port['id']
            options[:auto_correct] = port['auto-correct'] if port.key?('auto-correct')

            vm_config.vm.network 'forwarded_port', **options
          end
        end
      end
    end
  end
end
