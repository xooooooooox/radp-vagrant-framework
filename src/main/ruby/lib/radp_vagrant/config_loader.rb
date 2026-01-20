# frozen_string_literal: true

require 'yaml'

module RadpVagrant
  # Loads and validates YAML configuration with multi-file support
  # Supports: vagrant.yaml (base) + vagrant-{env}.yaml (environment-specific)
  module ConfigLoader
    class ConfigError < StandardError; end

    class << self
      # Load configuration with environment-based merging
      # @param config_dir [String] Directory containing config files
      # @param base_filename [String] Base config filename (default: vagrant.yaml)
      # @return [Hash] Merged configuration
      def load(config_dir, base_filename = 'vagrant.yaml')
        base_path = File.join(config_dir, base_filename)
        raise ConfigError, "Base configuration file not found: #{base_path}" unless File.exist?(base_path)

        # Load base config
        base_config = load_yaml_file(base_path)
        validate!(base_config)
        validate_base_config!(base_config)

        # Determine active environment
        env = base_config.dig('radp', 'env') || 'default'

        # Load environment-specific config if exists
        env_filename = base_filename.sub('.yaml', "-#{env}.yaml")
        env_path = File.join(config_dir, env_filename)

        if File.exist?(env_path)
          env_config = load_yaml_file(env_path)
          final_config = deep_merge(base_config, env_config)
        else
          final_config = base_config
        end

        # Store resolved env for reference
        final_config['radp'] ||= {}
        final_config['radp']['_resolved_env'] = env
        final_config['radp']['_config_dir'] = config_dir

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

        raise ConfigError, "Clusters must not be defined in base vagrant.yaml. " \
                           "Define clusters in vagrant-<env>.yaml instead."
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
