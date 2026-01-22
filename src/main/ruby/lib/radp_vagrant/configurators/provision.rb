# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM provisioners (shell, file)
    # Reference: https://developer.hashicorp.com/vagrant/docs/provisioning/shell
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
          options = {}
          options[:name] = name if name

          # run: once, always, never (renamed from freq)
          options[:run] = provision['run'] if provision['run']

          # privileged: run as root (default: false)
          options[:privileged] = provision.fetch('privileged', false)

          # Script content - one of inline or path required
          options[:inline] = provision['inline'] if provision['inline']
          options[:path] = provision['path'] if provision['path']

          # args: arguments to pass to the script
          options[:args] = provision['args'] if provision['args']

          # env: environment variables
          options[:env] = provision['env'] if provision['env']

          # Ordering options
          options[:before] = provision['before'] if provision['before']
          options[:after] = provision['after'] if provision['after']

          # Additional shell options
          options[:binary] = provision['binary'] if provision.key?('binary')
          options[:keep_color] = provision['keep-color'] if provision.key?('keep-color')
          options[:upload_path] = provision['upload-path'] if provision['upload-path']
          options[:reboot] = provision['reboot'] if provision.key?('reboot')
          options[:reset] = provision['reset'] if provision.key?('reset')
          options[:sensitive] = provision['sensitive'] if provision.key?('sensitive')

          vm_config.vm.provision 'shell', **options
        end

        def configure_file(vm_config, name, provision)
          options = {}
          options[:name] = name if name
          options[:source] = provision['source']
          options[:destination] = provision['destination']

          # run: once, always, never
          options[:run] = provision['run'] if provision['run']

          vm_config.vm.provision 'file', **options
        end
      end
    end
  end
end
