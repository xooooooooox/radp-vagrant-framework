# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module CLI
    # Validate command - validates YAML configuration files
    class Validate < Base
      def execute
        errors = []
        warnings = []

        # Check vagrant.yaml exists
        base_file = File.join(config_dir, 'vagrant.yaml')
        errors << "Base config file not found: #{base_file}" unless File.exist?(base_file)

        begin
          # Set environment override if specified
          ENV['RADP_VAGRANT_ENV'] = env_override if env_override

          # Load and validate using framework
          config = RadpVagrant::ConfigLoader.load(config_dir)

          env_name = config.dig('radp', '_resolved_env')
          env_file = File.join(config_dir, "vagrant-#{env_name}.yaml")

          puts "Base config:  #{base_file}"
          puts "Environment:  #{env_name}"
          puts "Env config:   #{env_file}#{File.exist?(env_file) ? '' : ' (not found)'}"
          puts ''

          vagrant_section = config.dig('radp', 'extend', 'vagrant')
          if vagrant_section
            validate_vagrant_section(vagrant_section, errors, warnings)
          else
            errors << 'No vagrant configuration found (radp.extend.vagrant is missing)'
          end
        rescue StandardError => e
          errors << "Configuration error: #{e.message}"
        end

        puts ''
        print_warnings(warnings)
        print_errors(errors)

        if errors.any?
          puts 'Validation FAILED'
          1
        else
          puts 'Validation OK'
          0
        end
      end

      private

      def validate_vagrant_section(vagrant_section, errors, warnings)
        clusters = vagrant_section.dig('config', 'clusters') || []

        if clusters.empty?
          warnings << 'No clusters defined'
        else
          validate_clusters(clusters, errors, warnings)

          puts "Clusters:     #{clusters.size}"
          total_guests = clusters.sum { |c| (c['guests'] || []).size }
          puts "Guests:       #{total_guests}"
        end

        # Check plugins
        plugins = vagrant_section['plugins'] || []
        required_plugins = plugins.select { |p| p['required'] }.map { |p| p['name'] }
        puts "Required plugins: #{required_plugins.join(', ')}" unless required_plugins.empty?
      end

      def validate_clusters(clusters, errors, warnings)
        # Check for duplicate cluster names
        cluster_names = clusters.map { |c| c['name'] }
        duplicates = cluster_names.select { |n| cluster_names.count(n) > 1 }.uniq
        duplicates.each { |name| errors << "Duplicate cluster name: #{name}" }

        # Check each cluster
        clusters.each do |cluster|
          cluster_name = cluster['name'] || 'unnamed'
          guests = cluster['guests'] || []

          if guests.empty?
            warnings << "Cluster '#{cluster_name}' has no guests"
          else
            validate_guests(guests, cluster_name, errors)
          end
        end
      end

      def validate_guests(guests, cluster_name, errors)
        # Check for duplicate guest IDs within cluster
        guest_ids = guests.map { |g| g['id'] }
        dup_guests = guest_ids.select { |id| guest_ids.count(id) > 1 }.uniq
        dup_guests.each { |id| errors << "Duplicate guest ID '#{id}' in cluster '#{cluster_name}'" }

        # Check each guest has required fields
        guests.each do |guest|
          errors << "Guest in cluster '#{cluster_name}' is missing 'id'" unless guest['id']
        end
      end

      def print_warnings(warnings)
        return if warnings.empty?

        puts 'Warnings:'
        warnings.each { |w| puts "  - #{w}" }
        puts ''
      end

      def print_errors(errors)
        return if errors.empty?

        puts 'Errors:'
        errors.each { |e| puts "  - #{e}" }
        puts ''
      end
    end
  end
end
