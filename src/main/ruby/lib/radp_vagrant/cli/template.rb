# frozen_string_literal: true

require_relative '../templates/registry'

module RadpVagrant
  module CLI
    # Template command - list and show available project templates
    class Template
      def initialize(subcommand, args = [])
        @subcommand = subcommand
        @args = args
      end

      def execute
        case @subcommand
        when 'list'
          list_templates
        when 'show'
          show_template(@args[0])
        else
          $stderr.puts "Unknown subcommand: #{@subcommand}"
          $stderr.puts "Usage: radp-vf template <list|show> [name]"
          1
        end
      end

      private

      def list_templates
        templates = Templates::Registry.list

        if templates.empty?
          puts "No templates found"
          puts ""
          puts "Template locations:"
          puts "  Builtin: $RADP_VF_HOME/templates/"
          puts "  User:    ~/.config/radp-vagrant/templates/"
          return 0
        end

        puts "Available Templates:"
        puts ""

        # Calculate column widths
        name_width = [templates.map { |t| t[:name].length }.max, 15].max
        version_width = [templates.map { |t| t[:version].length }.max, 7].max

        templates.each do |template|
          source_badge = template[:source] == 'user' ? ' [user]' : ''
          name_col = template[:name].ljust(name_width)
          version_col = template[:version].ljust(version_width)
          puts "  #{name_col}  #{version_col}  #{template[:desc]}#{source_badge}"
        end

        puts ""
        puts "Use 'radp-vf template show <name>' for details"
        0
      end

      def show_template(name)
        if name.nil? || name.empty?
          $stderr.puts "Error: Template name required"
          $stderr.puts "Usage: radp-vf template show <name>"
          return 1
        end

        template = Templates::Registry.get(name)

        unless template
          $stderr.puts "Error: Template '#{name}' not found"
          $stderr.puts ""
          $stderr.puts "Available templates:"
          Templates::Registry.list.each do |t|
            $stderr.puts "  - #{t[:name]}"
          end
          return 1
        end

        display_template(name, template)
        0
      end

      def display_template(name, template)
        puts "Template: #{name}"
        puts ""
        puts "  Description: #{template['desc'] || 'No description'}"
        puts "  Version:     #{template['version'] || '0.0.0'}"
        puts "  Source:      #{template['_source']}"
        puts "  Path:        #{template['_path']}"
        puts ""

        variables = template['variables'] || []
        if variables.empty?
          puts "  Variables:   (none)"
        else
          puts "  Variables:"
          variables.each do |var|
            required = var['required'] ? ' (required)' : ''
            type_info = var['type'] ? " [#{var['type']}]" : ''
            default = var['default'] ? " = #{var['default']}" : ''

            puts "    - #{var['name']}#{type_info}#{default}#{required}"
            puts "      #{var['desc']}" if var['desc']
          end
        end

        puts ""
        puts "Usage:"
        puts "  radp-vf init myproject --template #{name}"

        # Show example with variables
        var_examples = variables.select { |v| v['default'] }.take(2)
        if var_examples.any?
          example = var_examples.map { |v| "--set #{v['name']}=#{v['default']}" }.join(' ')
          puts "  radp-vf init myproject --template #{name} #{example}"
        end
      end
    end
  end
end
