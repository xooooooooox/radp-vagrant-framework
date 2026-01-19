# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      # Configurator for vagrant-bindfs plugin
      # Reference: https://github.com/gael-ian/vagrant-bindfs
      #
      # Note: vagrant-bindfs is configured per synced_folder, not globally.
      # Global options here are for reference/validation only.
      class Bindfs < Base
        class << self
          def plugin_name
            'vagrant-bindfs'
          end

          def configure(vagrant_config, options)
            # vagrant-bindfs is configured per synced_folder via:
            #   config.bindfs.bind_folder '/vagrant', '/home/vagrant/shared'
            #
            # Global configuration is not typically needed.
            # This configurator exists for consistency and future extensions.
            return unless options

            # Future: Add global default options if needed
            # config = vagrant_config.bindfs
            # set_if_present(config, :default_options, options, 'default_options')
          end
        end
      end
    end
  end
end
