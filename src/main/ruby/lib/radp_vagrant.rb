# frozen_string_literal: true

# RADP Vagrant Framework
# A YAML-driven framework for managing multi-machine Vagrant environments

require_relative 'radp_vagrant/version'
require_relative 'radp_vagrant/config_loader'
require_relative 'radp_vagrant/config_merger'
require_relative 'radp_vagrant/configurators/box'
require_relative 'radp_vagrant/configurators/provider'
require_relative 'radp_vagrant/configurators/network'
require_relative 'radp_vagrant/configurators/hostmanager'
require_relative 'radp_vagrant/configurators/synced_folder'
require_relative 'radp_vagrant/configurators/provision'
require_relative 'radp_vagrant/configurators/trigger'
require_relative 'radp_vagrant/configurators/plugin'

module RadpVagrant
  def self.banner
    version_str = VERSION.ljust(7)
    <<~BANNER
      \e[36m╔════════════════════════════════════════════════════════════════════════╗
      ║                                                                        ║
      ║   ██████╗  █████╗ ██████╗ ██████╗     ██╗   ██╗ █████╗  ██████╗       ║
      ║   ██╔══██╗██╔══██╗██╔══██╗██╔══██╗    ██║   ██║██╔══██╗██╔════╝       ║
      ║   ██████╔╝███████║██║  ██║██████╔╝    ██║   ██║███████║██║  ███╗      ║
      ║   ██╔══██╗██╔══██║██║  ██║██╔═══╝     ╚██╗ ██╔╝██╔══██║██║   ██║      ║
      ║   ██║  ██║██║  ██║██████╔╝██║          ╚████╔╝ ██║  ██║╚██████╔╝      ║
      ║   ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝           ╚═══╝  ╚═╝  ╚═╝ ╚═════╝       ║
      ║                                                                        ║
      ║                 RADP Vagrant Framework #{version_str}                      ║
      ╚════════════════════════════════════════════════════════════════════════╝\e[0m
    BANNER
  end

  class << self
    # Main entry point for Vagrant configuration
    # @param vagrant_config [Vagrant::Config] Vagrant configuration object
    # @param config_dir [String] Directory containing config files
    def configure(vagrant_config, config_dir)
      puts banner

      merged = build_merged_config(config_dir)
      return log_warn('No vagrant configuration found') unless merged

      log_info "Environment: #{merged['env']}"
      log_info "Config directory: #{merged['config_dir']}"

      # Configure plugins first
      Configurators::Plugin.configure(vagrant_config, merged['plugins'])

      # Collect all machine names for trigger only-on matching
      all_machine_names = merged['clusters'].flat_map do |cluster|
        cluster['guests'].map { |g| g.dig('provider', 'name') || g['id'] }
      end

      # Process each cluster
      merged['clusters'].each do |cluster|
        log_info "Processing cluster: #{cluster['name']}"
        cluster['guests'].each do |guest|
          define_guest(vagrant_config, guest, all_machine_names)
        end
      end

      log_info 'Configuration complete'
    end

    # Dump final merged configuration
    # @param config_dir [String] Directory containing config files
    # @param filter [String, nil] Filter by machine_name or guest_id
    # @param format [Symbol] Output format (:json or :yaml)
    def dump_config(config_dir, filter = nil, format: :json)
      merged = build_merged_config(config_dir)
      return puts "No vagrant configuration found" unless merged

      # Apply filter if specified (matches machine_name or guest_id)
      if filter
        merged['clusters'] = merged['clusters'].map do |cluster|
          filtered_guests = cluster['guests'].select do |guest|
            machine_name = guest.dig('provider', 'name') || guest['id']
            guest['id'] == filter || machine_name == filter
          end
          cluster.merge('guests' => filtered_guests)
        end.reject { |c| c['guests'].empty? }
      end

      output_config(merged, format)
    end

    # Generate standalone Vagrantfile from YAML configuration
    # @param config_dir [String] Directory containing config files
    # @param output_path [String, nil] Path to write Vagrantfile, or nil to return string
    # @return [String] Generated Vagrantfile content
    def generate_vagrantfile(config_dir, output_path = nil)
      require_relative 'radp_vagrant/generator'

      generator = Generator.new(config_dir)
      content = generator.generate

      if output_path
        File.write(output_path, content)
        puts "Generated Vagrantfile: #{output_path}"
      end

      content
    end

    # Build fully merged configuration (single source of truth)
    # @param config_dir [String] Directory containing config files
    # @return [Hash, nil] Merged configuration or nil if no vagrant config
    def build_merged_config(config_dir)
      config = ConfigLoader.load(config_dir)
      env = config.dig('radp', '_resolved_env') || 'default'

      vagrant_section = config.dig('radp', 'extend', 'vagrant')
      return nil unless vagrant_section

      common_config = vagrant_section.dig('config', 'common')
      clusters = vagrant_section.dig('config', 'clusters') || []

      # Build merged clusters with fully resolved guests
      merged_clusters = clusters.map do |cluster|
        cluster_name = cluster['name'] || 'default'
        cluster_common = cluster['common']
        guests = cluster['guests'] || []

        merged_guests = guests.filter_map do |guest|
          next if guest['enabled'] == false

          merge_guest_config(common_config, cluster_common, guest, cluster_name, env)
        end

        { 'name' => cluster_name, 'guests' => merged_guests }
      end

      {
        'env' => env,
        'config_dir' => config.dig('radp', '_config_dir'),
        'plugins' => vagrant_section['plugins'],
        'clusters' => merged_clusters
      }
    end

    private

    def merge_guest_config(global_common, cluster_common, guest, cluster_name, env)
      # Merge: global common -> cluster common -> guest
      merged = ConfigMerger.merge_guest_config(global_common, cluster_common, guest)

      # Inject context
      merged['_cluster_name'] = cluster_name
      merged['_env'] = env

      # Apply conventions for provider
      apply_provider_conventions(merged, cluster_name, env)

      merged
    end

    def apply_provider_conventions(guest, cluster_name, env)
      provider = guest['provider'] ||= {}

      # Convention: if group-id is empty, default to <env>/<cluster-name>
      provider['group-id'] ||= "#{env}/#{cluster_name}"

      # Convention: if name is empty, default to <env>-<cluster-name>-<guest-id>
      # Note: VirtualBox name uses dashes, group-id uses slashes
      provider['name'] ||= "#{env}-#{cluster_name}-#{guest['id']}"
    end

    def output_config(config, format)
      case format
      when :yaml
        require 'yaml'
        puts config.to_yaml
      else
        require 'json'
        puts JSON.pretty_generate(config)
      end
    end

    def define_guest(vagrant_config, guest, all_machine_names)
      guest_id = guest['id']
      env = guest['_env']
      # Use provider.name as machine name for uniqueness across clusters
      # This ensures $VAGRANT_DOTFILE_PATH/machines/<name> is unique
      machine_name = guest.dig('provider', 'name') || guest_id
      log_info "  Defining guest: #{machine_name} (id: #{guest_id})"

      vagrant_config.vm.define machine_name do |vm_config|
        Configurators::Box.configure(vm_config, guest)
        Configurators::Provider.configure(vm_config, guest)
        Configurators::Network.configure(vm_config, guest, env: env)
        Configurators::Hostmanager.configure(vm_config, guest)
        Configurators::SyncedFolder.configure(vm_config, guest)
        Configurators::Provision.configure(vm_config, guest)
        Configurators::Plugins::Hostmanager.configure_provisioner(vm_config)
        Configurators::Trigger.configure(vagrant_config, guest, all_machine_names: all_machine_names)
      end
    end

    def log_info(message)
      puts "\e[32m[INFO]\e[0m #{message}"
    end

    def log_warn(message)
      puts "\e[33m[WARN]\e[0m #{message}"
    end

    def log_error(message)
      puts "\e[31m[ERROR]\e[0m #{message}"
    end
  end
end
