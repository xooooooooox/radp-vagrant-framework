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

            # Core options
            set_if_present(config, :auto_update, options, 'auto_update')
            set_if_present(config, :no_remote, options, 'no_remote')
            set_if_present(config, :no_install, options, 'no_install')
            set_if_present(config, :auto_reboot, options, 'auto_reboot')
            set_if_present(config, :allow_downgrade, options, 'allow_downgrade')

            # ISO options
            set_if_present(config, :iso_path, options, 'iso_path')
            set_if_present(config, :iso_upload_path, options, 'iso_upload_path')
            set_if_present(config, :iso_mount_point, options, 'iso_mount_point')

            # Installer options
            set_if_present(config, :installer, options, 'installer')
            set_if_present(config, :installer_arguments, options, 'installer_arguments')
            set_if_present(config, :yes, options, 'yes')

            # Installer options hash (for distro-specific settings)
            if options['installer_options']
              config.installer_options = symbolize_keys(options['installer_options'])
            end

            # Installer hooks
            configure_installer_hooks(config, options['installer_hooks'])
          end

          private

          def configure_installer_hooks(config, hooks)
            return unless hooks.is_a?(Hash)

            hooks.each do |hook_name, script|
              next unless script

              # Convert hook name to symbol (e.g., 'before_install' -> :before_install)
              hook_sym = hook_name.to_sym
              config.installer_hooks[hook_sym] = lambda do |_installer, _command|
                system(script)
              end
            end
          end

          def symbolize_keys(hash)
            return hash unless hash.is_a?(Hash)

            hash.transform_keys(&:to_sym)
          end
        end
      end
    end
  end
end
