# frozen_string_literal: true

require 'yaml'

module RadpVagrant
  # Loads and validates YAML configuration with multi-file support
  # Supports: vagrant.yaml or config.yaml (base) + {base}-{env}.yaml (environment-specific)
  module ConfigLoader
    class ConfigError < StandardError; end

    # Supported base configuration filenames (in priority order)
    SUPPORTED_BASE_FILENAMES = %w[vagrant.yaml config.yaml].freeze

    class << self
      # Detect the base configuration filename
      # Priority: RADP_VAGRANT_CONFIG_BASE_FILENAME env var > auto-detect (vagrant.yaml > config.yaml)
      # @param config_dir [String] Directory containing config files
      # @return [String] Detected base filename
      # @raise [ConfigError] If no configuration file is found
      def detect_base_filename(config_dir)
        # Priority 1: Environment variable (supports any filename)
        if (env_filename = ENV['RADP_VAGRANT_CONFIG_BASE_FILENAME'])
          if File.exist?(File.join(config_dir, env_filename))
            return env_filename
          else
            raise ConfigError, "Specified config file not found: #{env_filename} in #{config_dir}"
          end
        end

        # Priority 2: Auto-detect from supported filenames
        SUPPORTED_BASE_FILENAMES.each do |filename|
          return filename if File.exist?(File.join(config_dir, filename))
        end

        raise ConfigError, "No configuration file found in #{config_dir}. " \
                           "Expected one of: #{SUPPORTED_BASE_FILENAMES.join(', ')}"
      end

      # Load configuration with environment-based merging
      # @param config_dir [String] Directory containing config files
      # @param base_filename [String, nil] Base config filename (auto-detected if nil)
      # @return [Hash] Merged configuration
      def load(config_dir, base_filename = nil)
        base_filename ||= detect_base_filename(config_dir)
        base_path = File.join(config_dir, base_filename)
        raise ConfigError, "Base configuration file not found: #{base_path}" unless File.exist?(base_path)

        # Load base config
        base_config = load_yaml_file(base_path)
        validate!(base_config)
        validate_base_config!(base_config)

        # Determine active environment
        # Priority: RADP_VAGRANT_ENV env var > radp.env in config > 'default'
        env = ENV['RADP_VAGRANT_ENV'] || base_config.dig('radp', 'env') || 'default'

        # Load environment-specific config if exists
        env_filename = base_filename.sub('.yaml', "-#{env}.yaml")
        env_path = File.join(config_dir, env_filename)

        if File.exist?(env_path)
          env_config = load_yaml_file(env_path)
          final_config = deep_merge(base_config, env_config)
        else
          final_config = base_config
        end

        # Merge plugins by name (later entries override/extend earlier ones)
        merge_plugins_by_name!(final_config)

        # Store resolved metadata for reference
        final_config['radp'] ||= {}
        final_config['radp']['_resolved_env'] = env
        final_config['radp']['_config_dir'] = config_dir
        final_config['radp']['_base_filename'] = base_filename

        validate!(final_config)
        final_config
      end

      # Load single file (for backward compatibility)
      def load_file(config_path)
        raise ConfigError, "Configuration file not found: #{config_path}" unless File.exist?(config_path)

        config = load_yaml_file(config_path)
        validate!(config)
        config
      end

      # Deep merge two hashes (arrays concatenate, hashes merge, scalars override)
      def deep_merge(base, override)
        return deep_dup(override) if base.nil?
        return deep_dup(base) if override.nil?

        return base + override if base.is_a?(Array) && override.is_a?(Array)
        return override unless base.is_a?(Hash) && override.is_a?(Hash)

        result = base.dup
        override.each do |key, value|
          result[key] = if result.key?(key)
                          deep_merge(result[key], value)
                        else
                          deep_dup(value)
                        end
        end
        result
      end

      private

      # Merge plugins with the same name
      # Later entries override/extend earlier ones (deep merge by name)
      def merge_plugins_by_name!(config)
        plugins = config.dig('radp', 'extend', 'vagrant', 'plugins')
        return unless plugins.is_a?(Array) && plugins.size > 1

        merged = {}
        plugins.each do |plugin|
          name = plugin['name']
          next unless name

          if merged.key?(name)
            merged[name] = deep_merge(merged[name], plugin)
          else
            merged[name] = deep_dup(plugin)
          end
        end

        config['radp']['extend']['vagrant']['plugins'] = merged.values
      end

      def load_yaml_file(path)
        YAML.load_file(path, permitted_classes: [Symbol])
      rescue Psych::SyntaxError => e
        raise ConfigError, "YAML syntax error in #{path}: #{e.message}"
      end

      def deep_dup(obj)
        case obj
        when Hash
          obj.transform_values { |v| deep_dup(v) }
        when Array
          obj.map { |v| deep_dup(v) }
        else
          obj
        end
      end

      def validate!(config)
        raise ConfigError, 'Configuration must be a Hash' unless config.is_a?(Hash)
        raise ConfigError, "Missing required 'radp' root key" unless config.key?('radp')

        vagrant_config = config.dig('radp', 'extend', 'vagrant')
        return if vagrant_config.nil?

        validate_plugins!(vagrant_config['plugins'])
        validate_clusters!(vagrant_config.dig('config', 'clusters'))
      end

      def validate_base_config!(config)
        clusters = config.dig('radp', 'extend', 'vagrant', 'config', 'clusters')
        return if clusters.nil? || clusters.empty?

        raise ConfigError, "Clusters must not be defined in base configuration file. " \
                           "Define clusters in the environment-specific file (e.g., vagrant-<env>.yaml or config-<env>.yaml)."
      end

      def validate_plugins!(plugins)
        return if plugins.nil?
        raise ConfigError, "'plugins' must be an array" unless plugins.is_a?(Array)

        plugins.each_with_index do |plugin, idx|
          raise ConfigError, "Plugin at index #{idx} must have a 'name'" unless plugin['name']
        end
      end

      def validate_clusters!(clusters)
        return if clusters.nil?
        raise ConfigError, "'clusters' must be an array" unless clusters.is_a?(Array)

        # Check for duplicate cluster names
        cluster_names = clusters.map { |c| c['name'] }.compact
        duplicates = cluster_names.group_by(&:itself).select { |_, v| v.size > 1 }.keys
        unless duplicates.empty?
          raise ConfigError, "Duplicate cluster names found: #{duplicates.join(', ')}"
        end

        clusters.each_with_index do |cluster, idx|
          validate_cluster!(cluster, idx)
        end
      end

      def validate_cluster!(cluster, idx)
        raise ConfigError, "Cluster at index #{idx} must be a Hash" unless cluster.is_a?(Hash)
        raise ConfigError, "Cluster at index #{idx} must have a 'name'" unless cluster['name']

        guests = cluster['guests']
        return if guests.nil?

        cluster_name = cluster['name']
        raise ConfigError, "Cluster '#{cluster_name}' guests must be an array" unless guests.is_a?(Array)

        # Check for duplicate guest IDs within this cluster
        guest_ids = guests.map { |g| g['id'] }.compact
        duplicates = guest_ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
        unless duplicates.empty?
          raise ConfigError, "Duplicate guest IDs in cluster '#{cluster_name}': #{duplicates.join(', ')}"
        end

        guests.each_with_index do |guest, guest_idx|
          raise ConfigError, "Guest at index #{guest_idx} in cluster '#{cluster_name}' must have an 'id'" unless guest['id']
        end
      end
    end
  end
end
