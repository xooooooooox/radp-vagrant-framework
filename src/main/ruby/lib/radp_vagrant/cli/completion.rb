# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module CLI
    # Completion command - provides completion data for shell completion
    class Completion < Base
      def initialize(config_dir, env_override: nil, type: 'machines', cluster: nil)
        super(config_dir, env_override: env_override)
        @type = type
        @cluster_filter = cluster
      end

      def execute
        # Use silent config loading for completion - no output on failure
        return 0 unless load_config_silent

        case @type
        when 'machines'
          puts all_machine_names.join("\n")
        when 'clusters'
          puts all_cluster_names.join("\n")
        when 'guests'
          puts guests_for_cluster(@cluster_filter).join("\n")
        when 'provisions'
          puts all_provision_names.join("\n")
        end
        0
      end

      private

      # Silent version of load_config - no output on failure
      # Used for completion to avoid polluting stdout
      def load_config_silent
        ENV['RADP_VAGRANT_ENV'] = env_override if env_override
        @merged_config = RadpVagrant.build_merged_config(config_dir)
        @merged_config ? true : false
      rescue StandardError
        false
      end

      def all_machine_names
        clusters.flat_map do |cluster|
          (cluster['guests'] || []).map do |guest|
            guest.dig('provider', 'name') || "#{env}-#{cluster['name']}-#{guest['id']}"
          end
        end
      end

      def all_cluster_names
        clusters.map { |c| c['name'] }
      end

      def all_provision_names
        names = []
        clusters.each do |cluster|
          (cluster['guests'] || []).each do |guest|
            (guest['provisions'] || []).each do |p|
              names << p['name'] if p['name'] && p['enabled'] != false
            end
          end
        end
        names.uniq
      end

      def guests_for_cluster(cluster_name)
        return [] unless cluster_name

        cluster = clusters.find { |c| c['name'] == cluster_name }
        return [] unless cluster

        (cluster['guests'] || []).map { |g| g['id'] }
      end
    end
  end
end
