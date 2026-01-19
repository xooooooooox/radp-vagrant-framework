# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      # Configurator for vagrant-hostmanager plugin
      # Reference: https://github.com/devopsgroup-io/vagrant-hostmanager
      class Hostmanager < Base
        class << self
          def plugin_name
            'vagrant-hostmanager'
          end

          def configure(vagrant_config, options)
            return unless options

            config = vagrant_config.hostmanager

            set_if_present(config, :enabled, options, 'enabled')
            set_if_present(config, :manage_host, options, 'manage_host')
            set_if_present(config, :manage_guest, options, 'manage_guest')
            set_if_present(config, :include_offline, options, 'include_offline')
            set_if_present(config, :ignore_private_ip, options, 'ignore_private_ip')
          end
        end
      end
    end
  end
end
