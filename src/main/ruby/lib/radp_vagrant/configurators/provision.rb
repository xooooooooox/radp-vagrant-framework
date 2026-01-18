# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM provisioners (shell, file)
    module Provision
      class << self
        def configure(vm_config, guest)
          provisions = guest['provisions']
          return unless provisions

          provisions.each do |provision|
            next unless provision['enabled']

            configure_provision(vm_config, provision)
          end
        end

        private

        def configure_provision(vm_config, provision)
          name = provision['name']
          provision_type = provision['type'] || 'shell'

          case provision_type
          when 'shell'
            configure_shell(vm_config, name, provision)
          when 'file'
            configure_file(vm_config, name, provision)
          end
        end

        def configure_shell(vm_config, name, provision)
          options = { name: name }
          options[:privileged] = provision['privileged'] if provision.key?('privileged')

          # freq maps to run (once, always, never)
          options[:run] = provision['freq'] if provision['freq']

          # inline or path
          options[:inline] = provision['inline'] if provision['inline']
          options[:path] = provision['path'] if provision['path']
          options[:args] = provision['args'] if provision['args']

          # ordering
          options[:before] = provision['before'] if provision['before']
          options[:after] = provision['after'] if provision['after']

          vm_config.vm.provision 'shell', **options
        end

        def configure_file(vm_config, name, provision)
          options = { name: name }
          options[:source] = provision['source']
          options[:destination] = provision['destination']

          vm_config.vm.provision 'file', **options
        end
      end
    end
  end
end
