# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures Vagrant plugins
    module Plugin
      # Extensible plugin configuration registry
      CONFIGURATORS = {
        'vagrant-hostmanager' => lambda { |config, opts|
          config.hostmanager.enabled = opts['enabled'] if opts.key?('enabled')
          config.hostmanager.manage_host = opts['manage-host'] if opts.key?('manage-host')
          config.hostmanager.manage_guest = opts['manage-guest'] if opts.key?('manage-guest')
          config.hostmanager.include_offline = opts['include-offline'] if opts.key?('include-offline')
          config.hostmanager.ignore_private_ip = opts['ignore-private-ip'] if opts.key?('ignore-private-ip')
        },
        'vagrant-vbguest' => lambda { |config, opts|
          config.vbguest.auto_update = opts['auto-update'] if opts.key?('auto-update')
          config.vbguest.no_remote = opts['no-remote'] if opts.key?('no-remote')
        },
        'vagrant-proxyconf' => lambda { |config, opts|
          config.proxy.http = opts['http'] if opts.key?('http')
          config.proxy.https = opts['https'] if opts.key?('https')
          config.proxy.no_proxy = opts['no-proxy'] if opts.key?('no-proxy')
        }
        # Add more plugins as needed
      }.freeze

      class << self
        def configure(vagrant_config, plugins)
          return unless plugins

          # Install and configure each plugin
          plugins.each do |plugin|
            next unless plugin['enabled']

            plugin_name = plugin['name']
            install_plugin(plugin_name)
            configure_plugin(vagrant_config, plugin_name, plugin['options'])
          end
        end

        private

        def install_plugin(plugin_name)
          return if Vagrant.has_plugin?(plugin_name)

          system("vagrant plugin install #{plugin_name}")
          raise "Plugin installation failed: #{plugin_name}" unless $?.success?
        end

        def configure_plugin(vagrant_config, plugin_name, options)
          return unless options

          configurator = CONFIGURATORS[plugin_name]
          configurator&.call(vagrant_config, options)
        end
      end

      # Register a new plugin configurator
      def self.register(plugin_name, &block)
        CONFIGURATORS[plugin_name] = block
      end
    end
  end
end
