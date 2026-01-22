# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      # Configurator for vagrant-bindfs plugin
      # Reference: https://github.com/gael-ian/vagrant-bindfs
      #
      # vagrant-bindfs is used to fix permission issues with NFS shares.
      # It remaps user/group ownership and permissions via bindfs mounts.
      #
      # Global options are configured here; per-folder bindfs is in synced_folder.rb
      class Bindfs < Base
        class << self
          def plugin_name
            'vagrant-bindfs'
          end

          def configure(vagrant_config, options)
            return unless options

            config = vagrant_config.bindfs

            # Debug mode
            config.debug = options['debug'] if options.key?('debug')

            # Force empty mountpoints (auto-clean before mounting)
            if options.key?('force_empty_mountpoints')
              config.force_empty_mountpoints = options['force_empty_mountpoints']
            end

            # Skip user/group existence validations
            if options['skip_validations']
              Array(options['skip_validations']).each do |validation|
                config.skip_validations << validation.to_sym
              end
            end

            # Bindfs installation options
            if options['bindfs_version']
              config.bindfs_version = options['bindfs_version']
            end

            if options.key?('install_bindfs_from_source')
              config.install_bindfs_from_source = options['install_bindfs_from_source']
            end

            # Default options for all bind_folder calls
            if options['default_options']
              config.default_options = symbolize_keys(options['default_options'])
            end
          end

          private

          def symbolize_keys(hash)
            return hash unless hash.is_a?(Hash)

            hash.transform_keys(&:to_sym)
          end
        end
      end
    end
  end
end
