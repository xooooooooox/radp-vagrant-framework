# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module CLI
    # Generate command - generates standalone Vagrantfile from YAML configuration
    class Generate < Base
      attr_reader :output

      def initialize(config_dir, env_override: nil, output: nil)
        super(config_dir, env_override: env_override)
        @output = output
      end

      def execute
        # Set environment override if specified
        ENV['RADP_VAGRANT_ENV'] = env_override if env_override

        # Output metadata to stderr
        $stderr.puts "Config Dir: #{config_dir}"
        $stderr.puts "Output:     #{output}" if output
        $stderr.puts ''

        begin
          content = RadpVagrant.generate_vagrantfile(config_dir)

          if output
            write_output(content)
            $stderr.puts "Generated: #{output}"
          else
            puts content
          end

          0
        rescue StandardError => e
          $stderr.puts "Error: #{e.message}"
          1
        end
      end

      private

      def write_output(content)
        # Ensure parent directory exists
        dir = File.dirname(output)
        FileUtils.mkdir_p(dir) unless dir == '.' || File.directory?(dir)

        File.write(output, content)
      end
    end
  end
end
