# frozen_string_literal: true

require_relative 'plugins/registry'

module RadpVagrant
  module Configurators
    # Configures Vagrant plugins
    # Reference: Plugin-specific documentation
    #
    # Plugin configurators are modularized under configurators/plugins/
    # Each plugin has its own file for better maintainability.
    #
    # To add a new plugin:
    # 1. Create a new file in configurators/plugins/ (e.g., my_plugin.rb)
    # 2. Inherit from Plugins::Base
    # 3. Implement .plugin_name and .configure methods
    # 4. Add the class to Plugins::Registry.plugin_classes
    module Plugin
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

          # Look up configurator in registry
          configurator = Plugins::Registry.find(plugin_name)

          if configurator
            configurator.configure(vagrant_config, options)
          else
            # For unknown plugins, try generic configuration
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

      # Register a new plugin configurator at runtime
      # @param configurator_class [Class] Class that extends Plugins::Base
      def self.register(configurator_class)
        Plugins::Registry.register(configurator_class)
      end
    end
  end
end
