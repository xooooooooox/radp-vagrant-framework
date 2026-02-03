# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module CLI
    # Resolve command - resolves cluster/guest-ids to machine names
    class Resolve < Base
      def initialize(config_dir, env_override: nil, clusters: [], guest_ids: [])
        super(config_dir, env_override: env_override)
        @cluster_filters = clusters
        @guest_id_filters = guest_ids
      end

      def execute
        return 1 unless load_config

        machine_names = resolve_machine_names
        puts machine_names.join("\n") unless machine_names.empty?
        0
      end

      private

      def resolve_machine_names
        results = []

        @cluster_filters.each do |cluster_name|
          cluster = clusters.find { |c| c['name'] == cluster_name }
          next unless cluster

          guests_to_include = if @guest_id_filters.empty?
                                cluster['guests'] || []
                              else
                                (cluster['guests'] || []).select { |g| @guest_id_filters.include?(g['id']) }
                              end

          guests_to_include.each do |guest|
            machine_name = guest.dig('provider', 'name') ||
                           "#{env}-#{cluster_name}-#{guest['id']}"
            results << machine_name
          end
        end

        results
      end
    end
  end
end
