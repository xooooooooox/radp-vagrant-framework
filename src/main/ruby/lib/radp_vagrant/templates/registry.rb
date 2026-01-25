# frozen_string_literal: true

require 'yaml'

module RadpVagrant
  module Templates
    # Registry for project templates
    # Discovers templates from builtin and user directories
    #
    # Template structure:
    #   templates/
    #   ├── base/
    #   │   ├── template.yaml    # Template metadata
    #   │   └── files/           # Template files to copy
    #   └── k8s-cluster/
    #       ├── template.yaml
    #       └── files/
    #
    # Supports dual registry:
    #   - Builtin templates: $RADP_VF_HOME/templates/
    #   - User templates: ~/.config/radp-vagrant/templates/
    module Registry
      # Builtin templates directory (relative to RADP_VF_HOME)
      # In development: radp-vagrant-framework/templates/
      # In installed: libexec/templates/
      BUILTIN_TEMPLATES_SUBDIR = 'templates'

      # User templates directory
      USER_TEMPLATES_DIR = File.expand_path('~/.config/radp-vagrant/templates')

      # Template metadata filename
      TEMPLATE_METADATA_FILE = 'template.yaml'

      class << self
        # List all available templates
        # @return [Array<Hash>] List of templates with name, desc, version, variables
        def list
          templates.map do |name, data|
            {
              name: name,
              desc: data['desc'] || 'No description',
              version: data['version'] || '0.0.0',
              source: data['_source'],
              variables: data['variables'] || []
            }
          end.sort_by { |t| t[:name] }
        end

        # Get template metadata by name
        # @param name [String] Template name
        # @return [Hash, nil] Template metadata or nil if not found
        def get(name)
          templates[name]
        end

        # Check if template exists
        # @param name [String] Template name
        # @return [Boolean]
        def exist?(name)
          templates.key?(name)
        end

        # Get path to template's files directory
        # @param name [String] Template name
        # @return [String, nil] Absolute path to files/ directory or nil
        def files_dir(name)
          template = get(name)
          return nil unless template

          File.join(template['_path'], 'files')
        end

        # Get path to template directory
        # @param name [String] Template name
        # @return [String, nil] Absolute path to template directory or nil
        def template_dir(name)
          template = get(name)
          template&.dig('_path')
        end

        # Clear cached templates (useful for testing)
        def reset!
          @templates = nil
        end

        private

        def templates
          @templates ||= load_all
        end

        def load_all
          result = {}

          # Load builtin templates first
          builtin_dir = builtin_templates_dir
          if builtin_dir && Dir.exist?(builtin_dir)
            load_templates_from(builtin_dir, 'builtin').each do |name, data|
              result[name] = data
            end
          end

          # Load user templates (override builtin if same name)
          if Dir.exist?(USER_TEMPLATES_DIR)
            load_templates_from(USER_TEMPLATES_DIR, 'user').each do |name, data|
              if result.key?(name)
                warn "[INFO] User template '#{name}' overrides builtin template"
              end
              result[name] = data
            end
          end

          result
        end

        def load_templates_from(dir, source)
          result = {}

          Dir.glob(File.join(dir, '*', TEMPLATE_METADATA_FILE)).each do |metadata_file|
            template_dir = File.dirname(metadata_file)
            name = File.basename(template_dir)

            begin
              data = YAML.load_file(metadata_file, permitted_classes: [Symbol])
              data['_path'] = template_dir
              data['_source'] = source
              result[name] = data
            rescue StandardError => e
              warn "[WARN] Failed to load template '#{name}': #{e.message}"
            end
          end

          result
        end

        def builtin_templates_dir
          radp_vf_home = ENV['RADP_VF_HOME']
          return nil unless radp_vf_home

          # Development mode: radp-vagrant-framework/templates/
          # Installed mode: libexec/templates/
          File.join(radp_vf_home, BUILTIN_TEMPLATES_SUBDIR)
        end
      end
    end
  end
end
