# frozen_string_literal: true

require 'yaml'

module RadpVagrant
  module Provisions
    # Registry for builtin provisions
    # Builtin provisions are identified by the 'radp:' prefix in the name
    module Registry
      BUILTIN_PREFIX = 'radp:'
      DEFINITIONS_DIR = File.join(__dir__, 'definitions')
      SCRIPTS_DIR = File.join(__dir__, 'scripts')

      class << self
        # Check if a provision name refers to a builtin provision
        # @param name [String] Provision name (e.g., 'radp:synology-nfs')
        # @return [Boolean]
        def builtin?(name)
          return false unless name.to_s.start_with?(BUILTIN_PREFIX)

          builtin_name = extract_name(name)
          provisions.key?(builtin_name)
        end

        # Extract the builtin name without prefix
        # @param name [String] Full provision name (e.g., 'radp:synology-nfs')
        # @return [String] Builtin name (e.g., 'synology-nfs')
        def extract_name(name)
          name.to_s.delete_prefix(BUILTIN_PREFIX)
        end

        # Get builtin provision definition
        # @param name [String] Provision name with prefix
        # @return [Hash, nil] Definition hash or nil if not found
        def get(name)
          builtin_name = extract_name(name)
          provisions[builtin_name]
        end

        # Get the script path for a builtin provision
        # @param name [String] Provision name with prefix
        # @return [String, nil] Absolute path to script or nil
        def script_path(name)
          definition = get(name)
          return nil unless definition && definition['script']

          File.join(SCRIPTS_DIR, definition['script'])
        end

        # List all available builtin provisions
        # @return [Array<Hash>] List of provisions with name and description
        def list
          provisions.map do |name, definition|
            {
              name: "#{BUILTIN_PREFIX}#{name}",
              description: definition['description'] || 'No description'
            }
          end
        end

        # Clear cached provisions (useful for testing)
        def reset!
          @provisions = nil
        end

        private

        def provisions
          @provisions ||= load_all
        end

        def load_all
          result = {}
          return result unless Dir.exist?(DEFINITIONS_DIR)

          Dir.glob(File.join(DEFINITIONS_DIR, '*.yaml')).each do |file|
            name = File.basename(file, '.yaml')
            begin
              result[name] = YAML.load_file(file, permitted_classes: [Symbol])
            rescue StandardError => e
              warn "[WARN] Failed to load builtin provision '#{name}': #{e.message}"
            end
          end
          result
        end
      end
    end
  end
end
