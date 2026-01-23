# frozen_string_literal: true

require 'yaml'

module RadpVagrant
  module Triggers
    # Registry for builtin triggers
    # Builtin triggers are identified by the 'radp:' prefix in the name
    #
    # Supports subdirectories with path naming:
    #   definitions/system/disable-swap.yaml -> radp:system/disable-swap
    module Registry
      BUILTIN_PREFIX = 'radp:'
      DEFINITIONS_DIR = File.join(__dir__, 'definitions')
      SCRIPTS_DIR = File.join(__dir__, 'scripts')

      class << self
        # Check if a trigger name refers to a builtin trigger
        # @param name [String] Trigger name (e.g., 'radp:system/disable-swap')
        # @return [Boolean]
        def builtin?(name)
          return false unless name.to_s.start_with?(BUILTIN_PREFIX)

          builtin_name = extract_name(name)
          triggers.key?(builtin_name)
        end

        # Extract the builtin name without prefix
        # @param name [String] Full trigger name (e.g., 'radp:system/disable-swap')
        # @return [String] Builtin name (e.g., 'system/disable-swap')
        def extract_name(name)
          name.to_s.delete_prefix(BUILTIN_PREFIX)
        end

        # Get builtin trigger definition
        # @param name [String] Trigger name with prefix
        # @return [Hash, nil] Definition hash or nil if not found
        def get(name)
          builtin_name = extract_name(name)
          triggers[builtin_name]
        end

        # Get the script path for a builtin trigger
        # Scripts are located in the same subdirectory structure as definitions
        # @param name [String] Trigger name with prefix
        # @return [String, nil] Absolute path to script or nil
        def script_path(name)
          definition = get(name)
          return nil unless definition

          # Check run-remote.script or run.script
          script_name = definition.dig('defaults', 'run-remote', 'script') ||
                        definition.dig('defaults', 'run', 'script')
          return nil unless script_name

          # Use stored original path to determine subdirectory
          original_path = definition['_original_path']
          subdir = File.dirname(original_path)
          subdir = '' if subdir == '.'

          # Build script path: scripts/{subdir}/{script}
          if subdir.empty?
            File.join(SCRIPTS_DIR, script_name)
          else
            File.join(SCRIPTS_DIR, subdir, script_name)
          end
        end

        # List all available builtin triggers
        # @return [Array<Hash>] List of triggers with name and description
        def list
          triggers.map do |name, definition|
            {
              name: "#{BUILTIN_PREFIX}#{name}",
              description: definition['desc'] || 'No description'
            }
          end
        end

        # Clear cached triggers (useful for testing)
        def reset!
          @triggers = nil
        end

        private

        def triggers
          @triggers ||= load_all
        end

        def load_all
          result = {}
          return result unless Dir.exist?(DEFINITIONS_DIR)

          # Recursively find all .yaml files
          Dir.glob(File.join(DEFINITIONS_DIR, '**', '*.yaml')).each do |file|
            # Extract relative path from DEFINITIONS_DIR as trigger name
            relative_path = file.sub("#{DEFINITIONS_DIR}/", '')
            original_path = relative_path.sub(/\.yaml$/, '')  # e.g., 'system/disable-swap'
            name = original_path  # Keep original path as name
            begin
              definition = YAML.load_file(file, permitted_classes: [Symbol])
              # Store original path for script lookup
              definition['_original_path'] = original_path
              result[name] = definition
            rescue StandardError => e
              warn "[WARN] Failed to load builtin trigger '#{name}': #{e.message}"
            end
          end
          result
        end
      end
    end
  end
end
