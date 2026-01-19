# frozen_string_literal: true

require_relative 'base'
require_relative 'hostmanager'
require_relative 'vbguest'
require_relative 'proxyconf'
require_relative 'bindfs'

module RadpVagrant
  module Configurators
    module Plugins
      # Registry for plugin configurators
      # Auto-discovers all plugin configurators and provides lookup
      module Registry
        class << self
          # Get all registered plugin configurators
          # @return [Hash<String, Class>] Map of plugin_name => configurator class
          def all
            @registry ||= build_registry
          end

          # Find configurator for a plugin
          # @param plugin_name [String] Plugin name (e.g., 'vagrant-hostmanager')
          # @return [Class, nil] Configurator class or nil if not found
          def find(plugin_name)
            all[plugin_name]
          end

          # Register a new plugin configurator
          # @param configurator_class [Class] Class that extends Plugins::Base
          def register(configurator_class)
            @registry ||= build_registry
            @registry[configurator_class.plugin_name] = configurator_class
          end

          # List all registered plugin names
          # @return [Array<String>] Plugin names
          def plugin_names
            all.keys
          end

          private

          def build_registry
            registry = {}

            # Find all subclasses of Base in the Plugins module
            plugin_classes.each do |klass|
              registry[klass.plugin_name] = klass
            end

            registry
          end

          def plugin_classes
            [
              Hostmanager,
              Vbguest,
              Proxyconf,
              Bindfs
            ]
          end
        end
      end
    end
  end
end
