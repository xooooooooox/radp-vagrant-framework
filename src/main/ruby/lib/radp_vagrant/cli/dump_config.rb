# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'base'

module RadpVagrant
  module CLI
    # DumpConfig command - exports merged configuration in JSON or YAML format
    class DumpConfig < Base
      attr_reader :filter, :format, :output

      def initialize(config_dir, env_override: nil, filter: nil, format: :json, output: nil)
        super(config_dir, env_override: env_override)
        @filter = filter
        @format = format.to_sym
        @output = output
      end

      def execute
        return 1 unless load_config

        # Output metadata to stderr
        $stderr.puts "Environment: #{env}"
        $stderr.puts "Config Dir:  #{config_dir}"
        $stderr.puts "Format:      #{format}"
        $stderr.puts "Filter:      #{filter}" if filter
        $stderr.puts "Output:      #{output}" if output
        $stderr.puts ''

        # Build output data
        output_data = build_output_data

        if output_data.nil?
          $stderr.puts 'No matching configuration found'
          return 1
        end

        # Format and output
        formatted = format_output(output_data)

        if output
          write_output(formatted)
          $stderr.puts "Written to: #{output}"
        else
          puts formatted
        end

        0
      end

      private

      def build_output_data
        data = {
          'env' => env,
          'config_dir' => config_dir,
          'plugins' => @merged_config['plugins'],
          'clusters' => clusters
        }

        return data unless filter

        # Apply filter (matches machine_name or guest_id)
        filtered_clusters = clusters.map do |cluster|
          filtered_guests = cluster['guests'].select do |guest|
            machine_name = guest.dig('provider', 'name') || guest['id']
            guest['id'] == filter || machine_name == filter || machine_name.include?(filter)
          end
          cluster.merge('guests' => filtered_guests)
        end.reject { |c| c['guests'].empty? }

        return nil if filtered_clusters.empty?

        data.merge('clusters' => filtered_clusters)
      end

      def format_output(data)
        case format
        when :yaml
          # Use YAML with cleaner output options
          data.to_yaml
        else
          # JSON with pretty print
          JSON.pretty_generate(data)
        end
      end

      def write_output(content)
        # Ensure parent directory exists
        dir = File.dirname(output)
        FileUtils.mkdir_p(dir) unless dir == '.' || File.directory?(dir)

        File.write(output, content)
      end
    end
  end
end
