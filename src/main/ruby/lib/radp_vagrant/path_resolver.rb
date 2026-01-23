# frozen_string_literal: true

module RadpVagrant
  # Unified path resolver for relative paths
  # Provides consistent two-level lookup: config_dir -> project_root
  module PathResolver
    class << self
      # Resolve a relative path with two-level lookup
      # @param relative_path [String] The relative path to resolve
      # @param config_dir [String] The configuration directory
      # @param warn_on_conflict [Boolean] Whether to warn if found in multiple locations
      # @return [String, nil] The resolved absolute path, or nil if not found
      def resolve(relative_path, config_dir, warn_on_conflict: true)
        return relative_path if absolute?(relative_path)
        return nil unless config_dir

        found = find_all(relative_path, config_dir)

        if found.size > 1 && warn_on_conflict
          warn "[WARN] '#{relative_path}' found in multiple locations:"
          warn "  - #{found[0]} (used)"
          found[1..].each { |f| warn "  - #{f} (ignored)" }
        end

        found.first
      end

      # Resolve a relative path, returning config-relative path if not found
      # (for error reporting by Vagrant)
      # @param relative_path [String] The relative path to resolve
      # @param config_dir [String] The configuration directory
      # @param warn_on_conflict [Boolean] Whether to warn if found in multiple locations
      # @return [String] The resolved path or config-relative fallback
      def resolve_with_fallback(relative_path, config_dir, warn_on_conflict: true)
        return relative_path if absolute?(relative_path)
        return relative_path unless config_dir

        resolved = resolve(relative_path, config_dir, warn_on_conflict: warn_on_conflict)
        resolved || File.expand_path(relative_path, config_dir)
      end

      # Check if a relative path exists in any search location
      # @param relative_path [String] The relative path to check
      # @param config_dir [String] The configuration directory
      # @return [Boolean] True if the path exists
      def exist?(relative_path, config_dir)
        return File.exist?(relative_path) if absolute?(relative_path)
        return false unless config_dir

        find_all(relative_path, config_dir).any?
      end

      # Get all search paths for a given config_dir
      # @param config_dir [String] The configuration directory
      # @return [Array<String>] List of search paths
      def search_paths(config_dir)
        return [] unless config_dir

        paths = [config_dir]
        project_root = File.dirname(config_dir)
        paths << project_root if project_root != config_dir
        paths
      end

      private

      def absolute?(path)
        return false unless path

        Pathname.new(path).absolute?
      end

      def find_all(relative_path, config_dir)
        found = []
        search_paths(config_dir).each do |base|
          full_path = File.expand_path(relative_path, base)
          found << full_path if File.exist?(full_path)
        end
        found
      end
    end
  end
end
