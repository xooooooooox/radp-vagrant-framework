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
        return 1 unless load_config

        case @type
        when 'machines'
          puts all_machine_names.join("\n")
        when 'clusters'
          puts all_cluster_names.join("\n")
        when 'guests'
          puts guests_for_cluster(@cluster_filter).join("\n")
        end
        0
      end

      private

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

      def guests_for_cluster(cluster_name)
        return [] unless cluster_name

        cluster = clusters.find { |c| c['name'] == cluster_name }
        return [] unless cluster

        (cluster['guests'] || []).map { |g| g['id'] }
      end
    end
  end
end
