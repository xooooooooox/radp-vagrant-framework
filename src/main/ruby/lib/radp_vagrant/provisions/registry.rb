# frozen_string_literal: true

require 'yaml'

module RadpVagrant
  module Provisions
    # Registry for builtin provisions
    # Builtin provisions are identified by the 'radp:' prefix in the name
    #
    # Supports subdirectories with path naming:
    #   definitions/nfs/mount.yaml -> radp:nfs/mount
    #   definitions/docker/setup.yaml -> radp:docker/setup
    module Registry
      BUILTIN_PREFIX = 'radp:'
      DEFINITIONS_DIR = File.join(__dir__, 'definitions')
      SCRIPTS_DIR = File.join(__dir__, 'scripts')

      class << self
        # Check if a provision name refers to a builtin provision
        # @param name [String] Provision name (e.g., 'radp:nfs-mount' or 'radp:nfs/mount')
        # @return [Boolean]
        def builtin?(name)
          return false unless name.to_s.start_with?(BUILTIN_PREFIX)

          builtin_name = extract_name(name)
          provisions.key?(builtin_name)
        end

        # Extract the builtin name without prefix
        # @param name [String] Full provision name (e.g., 'radp:nfs/mount')
        # @return [String] Builtin name (e.g., 'nfs/mount')
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
        # Scripts are located in the same subdirectory structure as definitions
        # @param name [String] Provision name with prefix
        # @return [String, nil] Absolute path to script or nil
        def script_path(name)
          definition = get(name)
          return nil unless definition && definition['script']

          builtin_name = extract_name(name)
          # Get subdirectory from provision name (e.g., 'nfs/mount' -> 'nfs')
          subdir = File.dirname(builtin_name)
          subdir = '' if subdir == '.'

          # Build script path: scripts/{subdir}/{script}
          if subdir.empty?
            File.join(SCRIPTS_DIR, definition['script'])
          else
            File.join(SCRIPTS_DIR, subdir, definition['script'])
          end
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

          # Recursively find all .yaml files
          Dir.glob(File.join(DEFINITIONS_DIR, '**', '*.yaml')).each do |file|
            # Extract relative path from DEFINITIONS_DIR as provision name
            relative_path = file.sub("#{DEFINITIONS_DIR}/", '')
            name = relative_path.sub(/\.yaml$/, '')
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
