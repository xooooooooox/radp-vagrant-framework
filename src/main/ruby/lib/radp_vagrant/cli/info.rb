# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module CLI
    # Info command - displays environment and configuration information
    class Info < Base
      attr_reader :radp_vf_home, :ruby_lib_dir

      def initialize(config_dir, env_override: nil, radp_vf_home: nil, ruby_lib_dir: nil)
        super(config_dir, env_override: env_override)
        @radp_vf_home = radp_vf_home
        @ruby_lib_dir = ruby_lib_dir
      end

      def execute
        puts 'RADP Vagrant Framework'
        puts ''

        display_framework_info
        display_env_vars
        display_resolved_config

        0
      end

      private

      def display_framework_info
        puts 'Framework:'
        puts "  Version:      #{RadpVagrant::VERSION}"
        puts "  RADP_VF_HOME: #{radp_vf_home || '(not set)'}"
        puts "  Vagrantfile:  #{ruby_lib_dir ? "#{ruby_lib_dir}/Vagrantfile" : '(not set)'}"
        puts ''
      end

      def display_env_vars
        puts 'Environment Variables:'
        puts "  RADP_VAGRANT_CONFIG_DIR: #{ENV['RADP_VAGRANT_CONFIG_DIR'] || '(not set)'}"
        puts "  RADP_VAGRANT_ENV:        #{ENV['RADP_VAGRANT_ENV'] || '(not set)'}"
      end

      def display_resolved_config
        return display_config_not_resolved unless config_dir && File.exist?("#{config_dir}/vagrant.yaml")

        # Set environment override if specified
        ENV['RADP_VAGRANT_ENV'] = env_override if env_override

        begin
          config = RadpVagrant::ConfigLoader.load(config_dir)
          resolved_env = config.dig('radp', '_resolved_env')
          env_source = determine_env_source(resolved_env)

          puts ''
          puts 'Resolved Configuration:'
          puts "  Config Dir:   #{config_dir}"
          puts "  Environment:  #{resolved_env || 'unknown'}"
          puts "                #{env_source}"
          puts ''
          puts 'Config Files:'
          puts "  Base: #{config_dir}/vagrant.yaml"

          env_file = "#{config_dir}/vagrant-#{resolved_env}.yaml"
          if resolved_env && File.exist?(env_file)
            puts "  Env:  #{env_file}"
          elsif resolved_env
            puts "  Env:  #{env_file} (not found)"
          end
        rescue StandardError => e
          puts ''
          puts "Configuration: (error: #{e.message})"
        end
      end

      def display_config_not_resolved
        puts ''
        puts 'Configuration: (not resolved)'
        puts '  Use -c <dir>, set RADP_VAGRANT_CONFIG_DIR, or run from a directory with config/vagrant.yaml'
        puts "  Or run 'radp-vf init <dir>' to create a new project."
      end

      def determine_env_source(resolved_env)
        return '(from -e flag)' if env_override && env_override == resolved_env
        return '(from RADP_VAGRANT_ENV)' if ENV['RADP_VAGRANT_ENV'] && ENV['RADP_VAGRANT_ENV'] == resolved_env

        '(from vagrant.yaml)'
      end
    end
  end
end
