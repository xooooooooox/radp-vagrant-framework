# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      # Configurator for vagrant-proxyconf plugin
      # Reference: https://github.com/tmatilai/vagrant-proxyconf
      class Proxyconf < Base
        class << self
          def plugin_name
            'vagrant-proxyconf'
          end

          def configure(vagrant_config, options)
            return unless options

            config = vagrant_config.proxy

            # enabled: false/nil disables the plugin
            # https://github.com/tmatilai/vagrant-proxyconf?tab=readme-ov-file#disabling-the-plugin
            if options.key?('enabled')
              config.enabled = options['enabled']
            end

            set_if_present(config, :http, options, 'http')
            set_if_present(config, :https, options, 'https')
            set_if_present(config, :no_proxy, options, 'no_proxy')
          end
        end
      end
    end
  end
end
