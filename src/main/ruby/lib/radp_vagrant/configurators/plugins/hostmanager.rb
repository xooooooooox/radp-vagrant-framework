# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      # Configurator for vagrant-hostmanager plugin
      # Reference: https://github.com/devopsgroup-io/vagrant-hostmanager
      class Hostmanager < Base
        # Track if provisioner mode is enabled
        @provisioner_enabled = false

        class << self
          attr_accessor :provisioner_enabled

          def plugin_name
            'vagrant-hostmanager'
          end

          def configure(vagrant_config, options)
            return unless options

            config = vagrant_config.hostmanager

            # Check for provisioner mode
            provisioner_opt = options['provisioner']
            self.provisioner_enabled = provisioner_opt == 'enabled' || provisioner_opt == true

            # Enforce mutual exclusivity: provisioner and enabled cannot both be true
            if provisioner_enabled && options['enabled'] == true
              puts "\e[33m[WARN]\e[0m vagrant-hostmanager: 'provisioner' and 'enabled' are mutually exclusive. " \
                   "Setting 'enabled: false' to use provisioner mode."
              config.enabled = false
            elsif provisioner_enabled
              # When using provisioner, always disable automatic mode
              config.enabled = false
            else
              set_if_present(config, :enabled, options, 'enabled')
            end

            set_if_present(config, :manage_host, options, 'manage_host')
            set_if_present(config, :manage_guest, options, 'manage_guest')
            set_if_present(config, :include_offline, options, 'include_offline')
            set_if_present(config, :ignore_private_ip, options, 'ignore_private_ip')
          end

          # Configure hostmanager as a provisioner for a VM
          # Called from define_guest when provisioner mode is enabled
          def configure_provisioner(vm_config)
            return unless provisioner_enabled

            vm_config.vm.provision :hostmanager
          end
        end
      end
    end
  end
end
