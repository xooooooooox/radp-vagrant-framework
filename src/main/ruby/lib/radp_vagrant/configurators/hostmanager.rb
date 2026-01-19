# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures per-guest hostmanager settings
    # Reference: https://github.com/devopsgroup-io/vagrant-hostmanager
    module Hostmanager
      class << self
        def configure(vm_config, guest)
          hostmanager = guest['hostmanager']
          return unless hostmanager

          # Configure aliases
          if hostmanager['aliases']
            vm_config.hostmanager.aliases = hostmanager['aliases']
          end

          # Configure IP resolver if needed
          configure_ip_resolver(vm_config, hostmanager['ip-resolver'])
        end

        private

        def configure_ip_resolver(vm_config, config)
          return unless config && config['enabled']

          vm_config.hostmanager.ip_resolver = proc do |vm, _resolving_vm|
            result = nil
            if vm.communicate.ready?
              vm.communicate.execute(config['execute']) do |_type, data|
                if (match = data.match(Regexp.new(config['regex'])))
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
