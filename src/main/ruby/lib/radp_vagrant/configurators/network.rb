# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM network settings
    module Network
      class << self
        def configure(vm_config, guest)
          network = guest['network']
          return unless network

          configure_hostname(vm_config, network)
          configure_private_network(vm_config, network['private-network'])
          configure_public_network(vm_config, network['public-network'])
          configure_forwarded_ports(vm_config, network['forwarded-ports'])
          configure_hostmanager(vm_config, network['hostmanager'])
        end

        private

        def configure_hostname(vm_config, network)
          vm_config.vm.hostname = network['hostname'] if network['hostname']
        end

        def configure_private_network(vm_config, config)
          return unless config && config['enabled']

          options = {}
          if config['type'] == 'dhcp'
            options[:type] = 'dhcp'
          else
            options[:ip] = config['ip'] if config['ip']
            options[:netmask] = config['netmask'] if config['netmask']
          end

          vm_config.vm.network 'private_network', **options
        end

        def configure_public_network(vm_config, config)
          return unless config && config['enabled']

          options = {}
          if config['type'] == 'dhcp'
            options[:type] = 'dhcp'
          else
            options[:ip] = config['ip'] if config['ip']
            options[:netmask] = config['netmask'] if config['netmask']
          end

          # Use 'bridge' key from config (supports array of bridges)
          options[:bridge] = config['bridge'] if config['bridge']
          options[:use_dhcp_assigned_default_route] = config['use-dhcp-assigned-default-route'] if config.key?('use-dhcp-assigned-default-route')

          vm_config.vm.network 'public_network', **options
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

            vm_config.vm.network 'forwarded_port', **options
          end
        end

        def configure_hostmanager(vm_config, config)
          return unless config && config['enabled']

          vm_config.hostmanager.aliases = config['aliases'] if config['aliases']

          return unless config['ip-resolver'] && config['ip-resolver']['enabled']

          vm_config.hostmanager.ip_resolver = proc do |vm, _resolving_vm|
            result = nil
            if vm.communicate.ready?
              vm.communicate.execute(config['ip-resolver']['execute']) do |_type, data|
                if (match = data.match(Regexp.new(config['ip-resolver']['regex'])))
                  result = match[1]
                end
              end
            end
            result
          end
        end
      end
    end
  end
end
