# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures Vagrant plugins
    # Reference: Plugin-specific documentation
    module Plugin
      # Extensible plugin configuration registry
      # Each configurator receives (vagrant_config, options_hash)
      # Options are passed as-is from YAML (matching official plugin docs)
      CONFIGURATORS = {
        # https://github.com/devopsgroup-io/vagrant-hostmanager
        'vagrant-hostmanager' => lambda { |config, opts|
          config.hostmanager.enabled = opts['enabled'] if opts.key?('enabled')
          config.hostmanager.manage_host = opts['manage_host'] if opts.key?('manage_host')
          config.hostmanager.manage_guest = opts['manage_guest'] if opts.key?('manage_guest')
          config.hostmanager.include_offline = opts['include_offline'] if opts.key?('include_offline')
          config.hostmanager.ignore_private_ip = opts['ignore_private_ip'] if opts.key?('ignore_private_ip')
        },

        # https://github.com/dotless-de/vagrant-vbguest
        'vagrant-vbguest' => lambda { |config, opts|
          config.vbguest.auto_update = opts['auto_update'] if opts.key?('auto_update')
          config.vbguest.no_remote = opts['no_remote'] if opts.key?('no_remote')
          if opts['install_options']
            config.vbguest.installer_options = opts['install_options']
          end
        },

        # https://github.com/tmatilai/vagrant-proxyconf
        'vagrant-proxyconf' => lambda { |config, opts|
          # enabled: false/nil disables the plugin
          # https://github.com/tmatilai/vagrant-proxyconf?tab=readme-ov-file#disabling-the-plugin
          if opts.key?('enabled')
            config.proxy.enabled = opts['enabled']
          end
          config.proxy.http = opts['http'] if opts.key?('http')
          config.proxy.https = opts['https'] if opts.key?('https')
          config.proxy.no_proxy = opts['no_proxy'] if opts.key?('no_proxy')
        },

        # https://github.com/gael-ian/vagrant-bindfs
        'vagrant-bindfs' => lambda { |config, opts|
          # vagrant-bindfs is configured per synced_folder, not globally
          # Options here are just for reference/validation
        }
      }.freeze

      class << self
        def configure(vagrant_config, plugins)
          return unless plugins

          plugins.each do |plugin|
            plugin_name = plugin['name']

            # Install if required
            install_plugin(plugin_name) if plugin['required']

            # Configure if options provided
            configure_plugin(vagrant_config, plugin_name, plugin['options'])
          end
        end

        private

        def install_plugin(plugin_name)
          # Skip if not running within Vagrant
          return unless defined?(Vagrant) && Vagrant.respond_to?(:has_plugin?)
          return if Vagrant.has_plugin?(plugin_name)

          puts "\e[33m[WARN]\e[0m Installing required plugin: #{plugin_name}"
          system("vagrant plugin install #{plugin_name}")
          raise "Plugin installation failed: #{plugin_name}" unless $?.success?

          # Restart Vagrant to load newly installed plugin
          puts "\e[32m[INFO]\e[0m Plugin #{plugin_name} installed. Please restart vagrant."
        end

        def configure_plugin(vagrant_config, plugin_name, options)
          return unless options

          configurator = CONFIGURATORS[plugin_name]
          if configurator
            configurator.call(vagrant_config, options)
          else
            # For unknown plugins, try generic configuration if the plugin
            # follows standard naming convention (config.plugin_name.option)
            configure_generic_plugin(vagrant_config, plugin_name, options)
          end
        end

        def configure_generic_plugin(vagrant_config, plugin_name, options)
          # Convert plugin name to config accessor (e.g., "vagrant-foo" -> "foo")
          config_name = plugin_name.sub(/^vagrant-/, '').gsub('-', '_')

          begin
            plugin_config = vagrant_config.send(config_name)
            options.each do |key, value|
              setter = "#{key}="
              plugin_config.send(setter, value) if plugin_config.respond_to?(setter)
            end
          rescue NoMethodError
            # Plugin doesn't follow standard naming, skip
          end
        end
      end

      # Register a new plugin configurator
      def self.register(plugin_name, &block)
        CONFIGURATORS[plugin_name] = block
      end
    end
  end
end
