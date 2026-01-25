# frozen_string_literal: true

require 'fileutils'
require_relative 'registry'

module RadpVagrant
  module Templates
    # Renders a template to a target directory with variable substitution
    #
    # Supports:
    #   - {{variable}} syntax in file contents
    #   - {{variable}} syntax in filenames
    #   - Default values from template.yaml
    #   - Required variable validation
    class Renderer
      attr_reader :template_name, :variables, :template

      def initialize(template_name, variables = {})
        @template_name = template_name
        @variables = variables
        @template = nil
      end

      # Render template to target directory
      # @param target_dir [String] Target directory path
      # @return [Hash] Result with status and messages
      def render_to(target_dir)
        # Load template metadata
        @template = Registry.get(template_name)
        unless @template
          return { success: false, error: "Template '#{template_name}' not found" }
        end

        # Get source files directory
        source_dir = Registry.files_dir(template_name)
        unless source_dir && Dir.exist?(source_dir)
          return { success: false, error: "Template '#{template_name}' has no files directory" }
        end

        # Merge defaults with provided variables
        merged_vars = merge_with_defaults

        # Validate required variables
        validation = validate_required(merged_vars)
        return validation unless validation[:success]

        # Render files
        render_files(source_dir, target_dir, merged_vars)
      end

      private

      def merge_with_defaults
        result = {}

        # Apply defaults from template definition
        (@template['variables'] || []).each do |var_def|
          name = var_def['name']
          result[name] = var_def['default'] if var_def.key?('default')
        end

        # Override with provided variables (string keys)
        @variables.each do |key, value|
          result[key.to_s] = value
        end

        result
      end

      def validate_required(vars)
        missing = []

        (@template['variables'] || []).each do |var_def|
          if var_def['required'] && !vars.key?(var_def['name'])
            missing << var_def['name']
          end
        end

        if missing.any?
          return {
            success: false,
            error: "Missing required variables: #{missing.join(', ')}"
          }
        end

        { success: true }
      end

      def render_files(source_dir, target_dir, vars)
        files_rendered = []

        # Find all files in source directory
        Dir.glob(File.join(source_dir, '**', '*'), File::FNM_DOTMATCH).each do |source_path|
          next if File.directory?(source_path)
          next if File.basename(source_path) == '.' || File.basename(source_path) == '..'

          # Calculate relative path
          relative_path = source_path.sub("#{source_dir}/", '')

          # Substitute variables in the path (for filenames like vagrant-{{env}}.yaml)
          rendered_path = substitute(relative_path, vars)

          # Calculate target path
          target_path = File.join(target_dir, rendered_path)

          # Create parent directory
          FileUtils.mkdir_p(File.dirname(target_path))

          # Read source and substitute content
          if text_file?(source_path)
            content = File.read(source_path)
            rendered_content = substitute(content, vars)
            File.write(target_path, rendered_content)
          else
            # Binary file - just copy
            FileUtils.cp(source_path, target_path)
          end

          # Preserve executable permission
          if File.executable?(source_path)
            FileUtils.chmod('+x', target_path)
          end

          files_rendered << rendered_path
        end

        { success: true, files: files_rendered }
      end

      def substitute(content, vars)
        # Replace {{var}} with values
        content.gsub(/\{\{(\w+)\}\}/) do |match|
          var_name = ::Regexp.last_match(1)
          if vars.key?(var_name)
            vars[var_name].to_s
          else
            # Keep original if variable not found
            match
          end
        end
      end

      def text_file?(path)
        # Check common text file extensions
        text_extensions = %w[
          .yaml .yml .json .xml .toml
          .rb .py .sh .bash .zsh
          .txt .md .rst
          .conf .cfg .ini
          .html .css .js
          .erb .haml .slim
        ]

        ext = File.extname(path).downcase
        return true if text_extensions.include?(ext)

        # For files without extension or unknown extension, try to detect
        return false unless File.exist?(path)

        # Check first 8KB for null bytes (binary indicator)
        begin
          sample = File.read(path, 8192) || ''
          !sample.include?("\x00")
        rescue StandardError
          false
        end
      end
    end
  end
end
