# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      # Configurator for vagrant-vbguest plugin
      # Reference: https://github.com/dotless-de/vagrant-vbguest
      class Vbguest < Base
        class << self
          def plugin_name
            'vagrant-vbguest'
          end

          def configure(vagrant_config, options)
            return unless options

            config = vagrant_config.vbguest

            set_if_present(config, :auto_update, options, 'auto_update')
            set_if_present(config, :no_remote, options, 'no_remote')

            # installer_options accepts a hash of options
            if options['install_options']
              config.installer_options = options['install_options']
            end
          end
        end
      end
    end
  end
end
