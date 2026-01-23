# frozen_string_literal: true

require 'yaml'
require_relative '../path_resolver'

module RadpVagrant
  module Provisions
    # Registry for user-defined provisions
    # User provisions are identified by the 'user:' prefix in the name
    # and are located in {config_dir}/provisions/ or {project_root}/provisions/
    #
    # Supports subdirectories with path naming:
    #   definitions/nfs/external-mount.yaml -> user:nfs/external-mount
    #   definitions/docker/setup.yaml -> user:docker/setup
    module UserRegistry
      USER_PREFIX = 'user:'
      PROVISIONS_DIR = 'provisions'
      DEFINITIONS_DIR = 'definitions'
      SCRIPTS_DIR = 'scripts'

      class << self
        # Check if a provision name refers to a user provision
        # @param name [String] Provision name (e.g., 'user:docker-setup' or 'user:nfs/external-mount')
        # @return [Boolean]
        def user_provision?(name)
          name.to_s.start_with?(USER_PREFIX)
        end

        # Extract the provision name without prefix
        # @param name [String] Full provision name (e.g., 'user:nfs/external-mount')
        # @return [String] Provision name (e.g., 'nfs/external-mount')
        def extract_name(name)
          name.to_s.delete_prefix(USER_PREFIX)
        end

        # Get user provision definition
        # @param name [String] Provision name with prefix (e.g., 'user:nfs/external-mount')
        # @param config_dir [String] Configuration directory
        # @return [Hash, nil] Definition hash or nil if not found
        def get(name, config_dir)
          return nil unless config_dir

          provision_name = extract_name(name)
          relative_path = File.join(PROVISIONS_DIR, DEFINITIONS_DIR, "#{provision_name}.yaml")

          definition_path = PathResolver.resolve(relative_path, config_dir, warn_on_conflict: true)
          return nil unless definition_path

          load_definition(definition_path, provision_name, config_dir)
        end

        # Get the script path for a user provision
        # Scripts are located in the same subdirectory structure as definitions
        # @param name [String] Provision name with prefix
        # @param config_dir [String] Configuration directory
        # @return [String, nil] Absolute path to script or nil
        def script_path(name, config_dir)
          return nil unless config_dir

          definition = get(name, config_dir)
          return nil unless definition && definition['script']

          provision_name = extract_name(name)
          # Get subdirectory from provision name (e.g., 'nfs/external-mount' -> 'nfs')
          subdir = File.dirname(provision_name)
          subdir = '' if subdir == '.'

          # Build script path: provisions/scripts/{subdir}/{script}
          script_relative = if subdir.empty?
                              File.join(PROVISIONS_DIR, SCRIPTS_DIR, definition['script'])
                            else
                              File.join(PROVISIONS_DIR, SCRIPTS_DIR, subdir, definition['script'])
                            end

          PathResolver.resolve(script_relative, config_dir, warn_on_conflict: true)
        end

        # Check if a user provision exists
        # @param name [String] Provision name with prefix
        # @param config_dir [String] Configuration directory
        # @return [Boolean]
        def exist?(name, config_dir)
          return false unless config_dir && user_provision?(name)

          provision_name = extract_name(name)
          relative_path = File.join(PROVISIONS_DIR, DEFINITIONS_DIR, "#{provision_name}.yaml")
          PathResolver.exist?(relative_path, config_dir)
        end

        # List all available user provisions (including subdirectories)
        # @param config_dir [String] Configuration directory
        # @return [Array<Hash>] List of provisions with name and description
        def list(config_dir)
          return [] unless config_dir

          provisions = {}

          # Search in all paths (config_dir first, then project_root)
          PathResolver.search_paths(config_dir).each do |base|
            definitions_dir = File.join(base, PROVISIONS_DIR, DEFINITIONS_DIR)
            next unless Dir.exist?(definitions_dir)

            # Recursively find all .yaml files
            Dir.glob(File.join(definitions_dir, '**', '*.yaml')).each do |file|
              # Extract relative path from definitions_dir as provision name
              relative_path = file.sub("#{definitions_dir}/", '')
              name = relative_path.sub(/\.yaml$/, '')

              # Only add if not already found (config_dir takes precedence)
              next if provisions.key?(name)

              begin
                definition = YAML.load_file(file, permitted_classes: [Symbol])
                provisions[name] = {
                  name: "#{USER_PREFIX}#{name}",
                  description: definition['description'] || 'No description',
                  location: file
                }
              rescue StandardError => e
                warn "[WARN] Failed to load user provision '#{name}': #{e.message}"
              end
            end
          end

          provisions.values
        end

        private

        def load_definition(path, provision_name, config_dir)
          definition = YAML.load_file(path, permitted_classes: [Symbol])
          # Store the base directory for script resolution
          definition['_base_dir'] = File.dirname(File.dirname(File.dirname(path)))
          definition['_provision_name'] = provision_name
          definition
        rescue StandardError => e
          warn "[WARN] Failed to load user provision '#{provision_name}': #{e.message}"
          nil
        end
      end
    end
  end
end
