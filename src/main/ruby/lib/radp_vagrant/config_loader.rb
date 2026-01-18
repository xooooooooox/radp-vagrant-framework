# frozen_string_literal: true

require 'yaml'

module RadpVagrant
  # Loads and validates YAML configuration
  module ConfigLoader
    class ConfigError < StandardError; end

    class << self
      def load(config_path)
        raise ConfigError, "Configuration file not found: #{config_path}" unless File.exist?(config_path)

        config = YAML.load_file(config_path, permitted_classes: [Symbol])
        validate!(config)
        config
      rescue Psych::SyntaxError => e
        raise ConfigError, "YAML syntax error in #{config_path}: #{e.message}"
      end

      private

      def validate!(config)
        raise ConfigError, 'Configuration must be a Hash' unless config.is_a?(Hash)
        raise ConfigError, "Missing required 'radp' root key" unless config.key?('radp')

        vagrant_config = config.dig('radp', 'extend', 'vagrant')
        return if vagrant_config.nil?

        validate_plugins!(vagrant_config['plugins'])
        validate_clusters!(vagrant_config.dig('config', 'clusters'))
      end

      def validate_plugins!(plugins)
        return if plugins.nil?
        raise ConfigError, "'plugins' must be an array" unless plugins.is_a?(Array)
      end

      def validate_clusters!(clusters)
        return if clusters.nil?
        raise ConfigError, "'clusters' must be an array" unless clusters.is_a?(Array)

        clusters.each_with_index do |cluster, idx|
          validate_cluster!(cluster, idx)
        end
      end

      def validate_cluster!(cluster, idx)
        raise ConfigError, "Cluster at index #{idx} must be a Hash" unless cluster.is_a?(Hash)
        raise ConfigError, "Cluster at index #{idx} must have a 'name'" unless cluster['name']

        guests = cluster['guests']
        return if guests.nil?

        raise ConfigError, "Cluster '#{cluster['name']}' guests must be an array" unless guests.is_a?(Array)

        guests.each_with_index do |guest, guest_idx|
          raise ConfigError, "Guest at index #{guest_idx} in cluster '#{cluster['name']}' must have an 'id'" unless guest['id']
        end
      end
    end
  end
end
