# frozen_string_literal: true

module RadpVagrant
  module Configurators
    module Plugins
      # Base class for plugin configurators
      # Each plugin configurator should inherit from this class
      class Base
        class << self
          # Plugin name (e.g., 'vagrant-hostmanager')
          # Subclasses must override this method
          def plugin_name
            raise NotImplementedError, "#{self} must implement .plugin_name"
          end

          # Configure the plugin
          # @param vagrant_config [Vagrant::Config] Vagrant configuration object
          # @param options [Hash] Plugin options from YAML
          def configure(vagrant_config, options)
            raise NotImplementedError, "#{self} must implement .configure"
          end

          # Helper method to safely set config option if key exists
          def set_if_present(config, method, options, key)
            return unless options.key?(key)

            config.send("#{method}=", options[key])
          end
        end
      end
    end
  end
end
