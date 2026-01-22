# frozen_string_literal: true

require 'pathname'

module RadpVagrant
  module Configurators
    # Configures VM provisioners (shell, file)
    # Reference: https://developer.hashicorp.com/vagrant/docs/provisioning/shell
    module Provision
      class << self
        def configure(vm_config, guest)
          provisions = guest['provisions']
          return unless provisions

          config_dir = guest['_config_dir']

          provisions.each do |provision|
            next unless provision['enabled']

            configure_provision(vm_config, provision, config_dir)
          end
        end

        private

        def configure_provision(vm_config, provision, config_dir)
          name = provision['name']
          provision_type = provision['type'] || 'shell'

          case provision_type
          when 'shell'
            configure_shell(vm_config, name, provision, config_dir)
          when 'file'
            configure_file(vm_config, name, provision, config_dir)
          end
        end

        def configure_shell(vm_config, name, provision, config_dir)
          options = {}
          options[:name] = name if name

          # run: once, always, never (renamed from freq)
          options[:run] = provision['run'] if provision['run']

          # privileged: run as root (default: false)
          options[:privileged] = provision.fetch('privileged', false)

          # Script content - one of inline or path required
          options[:inline] = provision['inline'] if provision['inline']
          options[:path] = resolve_path(provision['path'], config_dir) if provision['path']

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

        def configure_file(vm_config, name, provision, config_dir)
          options = {}
          options[:name] = name if name
          options[:source] = resolve_path(provision['source'], config_dir)
          options[:destination] = provision['destination']

          # run: once, always, never
          options[:run] = provision['run'] if provision['run']

          vm_config.vm.provision 'file', **options
        end

        # Resolve relative paths against config directory or project root
        # Absolute paths are returned as-is
        #
        # Resolution order:
        # 1. If path exists relative to config_dir, use it (scripts inside config dir)
        # 2. If path exists relative to config_dir's parent, use it (standard project structure)
        # 3. Otherwise, return path relative to config_dir (let Vagrant report the error)
        def resolve_path(path, config_dir)
          return path unless path
          return path if Pathname.new(path).absolute?
          return path unless config_dir

          # Try 1: relative to config directory (e.g., config/scripts/setup.sh)
          config_relative = File.expand_path(path, config_dir)
          return config_relative if File.exist?(config_relative)

          # Try 2: relative to project root (e.g., project/scripts/setup.sh)
          project_root = File.dirname(config_dir)
          project_relative = File.expand_path(path, project_root)
          return project_relative if File.exist?(project_relative)

          # Fallback: return config-relative path (Vagrant will report file not found)
          config_relative
        end
      end
    end
  end
end
