# frozen_string_literal: true

require_relative '../path_resolver'
require_relative '../provisions/registry'
require_relative '../provisions/user_registry'

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

            # Resolve builtin or user provisions
            resolved_provision = resolve_provision(provision, config_dir)
            configure_provision(vm_config, resolved_provision, config_dir)
          end
        end

        private

        # Resolve provision by checking builtin (radp:) and user (user:) prefixes
        # @param provision [Hash] The provision configuration
        # @param config_dir [String] The configuration directory
        # @return [Hash] The resolved provision with defaults merged
        def resolve_provision(provision, config_dir)
          name = provision['name']

          # Check for builtin provision (radp:)
          if Provisions::Registry.builtin?(name)
            return resolve_builtin(provision)
          end

          # Check for user provision (user:)
          if Provisions::UserRegistry.user_provision?(name)
            return resolve_user_provision(provision, config_dir)
          end

          # Regular provision, no resolution needed
          provision
        end

        # Resolve builtin provision by merging definition defaults with user config
        # User config takes precedence over definition defaults
        def resolve_builtin(provision)
          name = provision['name']
          definition = Provisions::Registry.get(name)
          return provision unless definition

          resolved = merge_with_defaults(provision, definition)
          resolved['_builtin'] = true

          # Only set path if definition uses script (not inline)
          # User-provided inline or path takes precedence
          unless resolved['inline'] || resolved['path']
            script_path = Provisions::Registry.script_path(name)
            resolved['path'] = script_path if script_path
          end

          resolved
        end

        # Resolve user provision by merging definition defaults with user config
        # User config takes precedence over definition defaults
        def resolve_user_provision(provision, config_dir)
          name = provision['name']
          definition = Provisions::UserRegistry.get(name, config_dir)
          return provision unless definition

          resolved = merge_with_defaults(provision, definition)
          resolved['_user_provision'] = true

          # Only set path if definition uses script (not inline)
          # User-provided inline or path takes precedence
          unless resolved['inline'] || resolved['path']
            script_path = Provisions::UserRegistry.script_path(name, config_dir)
            resolved['path'] = script_path if script_path
          end

          resolved
        end

        # Merge user config with definition defaults
        # Definition format:
        #   desc: Human-readable description
        #   defaults:
        #     privileged: true
        #     run: once
        #     env:
        #       required: [{name, desc}]
        #       optional: [{name, value, desc}]
        #     script: xxx.sh      # Use external script file
        #     # OR
        #     inline: |           # Use inline script
        #       echo "Hello"
        #
        # @param provision [Hash] User provision configuration
        # @param definition [Hash] Definition with defaults
        # @return [Hash] Merged configuration
        def merge_with_defaults(provision, definition)
          resolved = {}
          defaults = definition['defaults'] || {}

          # Apply simple defaults (privileged, run)
          resolved['privileged'] = defaults['privileged'] if defaults.key?('privileged')
          resolved['run'] = defaults['run'] if defaults.key?('run')

          # Apply inline from defaults (if no script is defined)
          resolved['inline'] = defaults['inline'] if defaults.key?('inline')

          # Apply args from defaults
          resolved['args'] = defaults['args'] if defaults.key?('args')

          # Merge user config (user values override defaults)
          provision.each do |key, value|
            resolved[key] = value
          end

          # Apply optional env defaults
          optional_env = defaults.dig('env', 'optional')
          resolved['env'] = merge_optional_env(resolved['env'], optional_env)

          resolved
        end

        # Merge optional env defaults with user-provided env
        # User-provided env values take precedence over optional env defaults
        # @param user_env [Hash, nil] User-provided environment variables
        # @param optional_env [Array<Hash>, nil] Optional env definitions with value defaults
        # @return [Hash] Merged environment variables
        def merge_optional_env(user_env, optional_env)
          return user_env || {} unless optional_env

          merged = {}

          # First, apply optional env defaults (using 'value' field)
          optional_env.each do |opt|
            name = opt['name']
            default_value = opt['value']
            merged[name] = default_value unless default_value.nil?
          end

          # Then, override with user-provided values
          if user_env
            user_env.each do |key, value|
              merged[key] = value
            end
          end

          merged
        end

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

          # run: once, always, never (renamed from freq)
          options[:run] = provision['run'] if provision['run']

          # privileged: run as root (default: false)
          options[:privileged] = provision.fetch('privileged', false)

          # Script content - one of inline or path required
          options[:inline] = provision['inline'] if provision['inline']
          if provision['path']
            # Builtin/user provisions already have absolute paths resolved
            if provision['_builtin'] || provision['_user_provision']
              options[:path] = provision['path']
            else
              options[:path] = PathResolver.resolve_with_fallback(provision['path'], config_dir)
            end
          end

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

          # Use name as first argument for --provision-with compatibility
          # Vagrant only recognizes provisioner names when defined this way
          if name
            vm_config.vm.provision name, type: 'shell', **options
          else
            vm_config.vm.provision 'shell', **options
          end
        end

        def configure_file(vm_config, name, provision, config_dir)
          options = {}
          options[:source] = PathResolver.resolve_with_fallback(provision['source'], config_dir)
          options[:destination] = provision['destination']

          # run: once, always, never
          options[:run] = provision['run'] if provision['run']

          # Use name as first argument for --provision-with compatibility
          if name
            vm_config.vm.provision name, type: 'file', **options
          else
            vm_config.vm.provision 'file', **options
          end
        end
      end
    end
  end
end
