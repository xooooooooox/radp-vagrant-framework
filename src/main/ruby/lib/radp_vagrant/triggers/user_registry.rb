# frozen_string_literal: true

require 'yaml'
require_relative '../path_resolver'

module RadpVagrant
  module Triggers
    # Registry for user-defined triggers
    # User triggers are identified by the 'user:' prefix in the name
    # and are located in {config_dir}/triggers/ or {project_root}/triggers/
    #
    # Supports subdirectories with path naming:
    #   definitions/system/cleanup.yaml -> user:system/cleanup
    #   definitions/network/setup.yaml -> user:network/setup
    module UserRegistry
      USER_PREFIX = 'user:'
      TRIGGERS_DIR = 'triggers'
      DEFINITIONS_DIR = 'definitions'
      SCRIPTS_DIR = 'scripts'

      class << self
        # Check if a trigger name refers to a user trigger
        # @param name [String] Trigger name (e.g., 'user:cleanup' or 'user:system/cleanup')
        # @return [Boolean]
        def user_trigger?(name)
          name.to_s.start_with?(USER_PREFIX)
        end

        # Extract the trigger name without prefix
        # @param name [String] Full trigger name (e.g., 'user:system/cleanup')
        # @return [String] Trigger name (e.g., 'system/cleanup')
        def extract_name(name)
          name.to_s.delete_prefix(USER_PREFIX)
        end

        # Get user trigger definition
        # @param name [String] Trigger name with prefix (e.g., 'user:system/cleanup')
        # @param config_dir [String] Configuration directory
        # @return [Hash, nil] Definition hash or nil if not found
        def get(name, config_dir)
          return nil unless config_dir

          trigger_name = extract_name(name)
          relative_path = File.join(TRIGGERS_DIR, DEFINITIONS_DIR, "#{trigger_name}.yaml")

          definition_path = PathResolver.resolve(relative_path, config_dir, warn_on_conflict: true)
          return nil unless definition_path

          load_definition(definition_path, trigger_name, config_dir)
        end

        # Get the script path for a user trigger
        # Scripts are located in the same subdirectory structure as definitions
        # @param name [String] Trigger name with prefix
        # @param config_dir [String] Configuration directory
        # @return [String, nil] Absolute path to script or nil
        def script_path(name, config_dir)
          return nil unless config_dir

          definition = get(name, config_dir)
          # Check run-remote.script or run.script
          script_name = definition&.dig('defaults', 'run-remote', 'script') ||
                        definition&.dig('defaults', 'run', 'script')
          return nil unless script_name

          trigger_name = extract_name(name)
          # Get subdirectory from trigger name (e.g., 'system/cleanup' -> 'system')
          subdir = File.dirname(trigger_name)
          subdir = '' if subdir == '.'

          # Build script path: triggers/scripts/{subdir}/{script}
          script_relative = if subdir.empty?
                              File.join(TRIGGERS_DIR, SCRIPTS_DIR, script_name)
                            else
                              File.join(TRIGGERS_DIR, SCRIPTS_DIR, subdir, script_name)
                            end

          PathResolver.resolve(script_relative, config_dir, warn_on_conflict: true)
        end

        # Check if a user trigger exists
        # @param name [String] Trigger name with prefix
        # @param config_dir [String] Configuration directory
        # @return [Boolean]
        def exist?(name, config_dir)
          return false unless config_dir && user_trigger?(name)

          trigger_name = extract_name(name)
          relative_path = File.join(TRIGGERS_DIR, DEFINITIONS_DIR, "#{trigger_name}.yaml")
          PathResolver.exist?(relative_path, config_dir)
        end

        # List all available user triggers (including subdirectories)
        # @param config_dir [String] Configuration directory
        # @return [Array<Hash>] List of triggers with name and description
        def list(config_dir)
          return [] unless config_dir

          triggers = {}

          # Search in all paths (config_dir first, then project_root)
          PathResolver.search_paths(config_dir).each do |base|
            definitions_dir = File.join(base, TRIGGERS_DIR, DEFINITIONS_DIR)
            next unless Dir.exist?(definitions_dir)

            # Recursively find all .yaml files
            Dir.glob(File.join(definitions_dir, '**', '*.yaml')).each do |file|
              # Extract relative path from definitions_dir as trigger name
              relative_path = file.sub("#{definitions_dir}/", '')
              name = relative_path.sub(/\.yaml$/, '')

              # Only add if not already found (config_dir takes precedence)
              next if triggers.key?(name)

              begin
                definition = YAML.load_file(file, permitted_classes: [Symbol])
                triggers[name] = {
                  name: "#{USER_PREFIX}#{name}",
                  description: definition['desc'] || 'No description',
                  location: file
                }
              rescue StandardError => e
                warn "[WARN] Failed to load user trigger '#{name}': #{e.message}"
              end
            end
          end

          triggers.values
        end

        private

        def load_definition(path, trigger_name, config_dir)
          definition = YAML.load_file(path, permitted_classes: [Symbol])
          # Store the base directory for script resolution
          definition['_base_dir'] = File.dirname(File.dirname(File.dirname(path)))
          definition['_trigger_name'] = trigger_name
          definition
        rescue StandardError => e
          warn "[WARN] Failed to load user trigger '#{trigger_name}': #{e.message}"
          nil
        end
      end
    end
  end
end
