# frozen_string_literal: true

# RADP Vagrant Framework
# A YAML-driven framework for managing multi-machine Vagrant environments

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
  BANNER = <<~BANNER
    \e[36m╔════════════════════════════════════════════════════════════════════════╗
    ║                                                                        ║
    ║   ██████╗  █████╗ ██████╗ ██████╗     ██╗   ██╗ █████╗  ██████╗       ║
    ║   ██╔══██╗██╔══██╗██╔══██╗██╔══██╗    ██║   ██║██╔══██╗██╔════╝       ║
    ║   ██████╔╝███████║██║  ██║██████╔╝    ██║   ██║███████║██║  ███╗      ║
    ║   ██╔══██╗██╔══██║██║  ██║██╔═══╝     ╚██╗ ██╔╝██╔══██║██║   ██║      ║
    ║   ██║  ██║██║  ██║██████╔╝██║          ╚████╔╝ ██║  ██║╚██████╔╝      ║
    ║   ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝           ╚═══╝  ╚═╝  ╚═╝ ╚═════╝       ║
    ║                                                                        ║
    ║                    RADP Vagrant Framework v2.0                         ║
    ╚════════════════════════════════════════════════════════════════════════╝\e[0m
  BANNER

  class << self
    # Main entry point for Vagrant configuration
    # @param vagrant_config [Vagrant::Config] Vagrant configuration object
    # @param config_dir [String] Directory containing config files
    def configure(vagrant_config, config_dir)
      puts BANNER

      # Load configuration (base + environment-specific)
      config = ConfigLoader.load(config_dir)
      env = config.dig('radp', '_resolved_env') || 'default'

      log_info "Environment: #{env}"
      log_info "Config directory: #{config_dir}"

      vagrant_section = config.dig('radp', 'extend', 'vagrant')
      return log_warn('No vagrant configuration found') unless vagrant_section

      # Configure plugins first
      Configurators::Plugin.configure(vagrant_config, vagrant_section['plugins'])

      # Get configuration sections
      common_config = vagrant_section.dig('config', 'common')
      clusters = vagrant_section.dig('config', 'clusters') || []

      # Collect all machine names for trigger only-on matching
      all_machine_names = collect_machine_names(clusters, common_config, env)

      # Process each cluster
      clusters.each do |cluster|
        process_cluster(vagrant_config, cluster, common_config, all_machine_names, env)
      end

      log_info 'Configuration complete'
    end

    # Debug: dump final configuration for a guest
    # @param config_dir [String] Directory containing config files
    # @param guest_id [String, nil] Specific guest to dump, or nil for all
    def dump_config(config_dir, guest_id = nil)
      require 'json'

      config = ConfigLoader.load(config_dir)
      env = config.dig('radp', '_resolved_env') || 'default'

      vagrant_section = config.dig('radp', 'extend', 'vagrant')
      return puts "No vagrant configuration found" unless vagrant_section

      common_config = vagrant_section.dig('config', 'common')
      clusters = vagrant_section.dig('config', 'clusters') || []

      result = {
        env: env,
        plugins: vagrant_section['plugins'],
        guests: []
      }

      clusters.each do |cluster|
        cluster_name = cluster['name']
        cluster_common = cluster['common']
        guests = cluster['guests'] || []

        guests.each do |guest|
          next if guest['enabled'] == false
          next if guest_id && guest['id'] != guest_id

          merged = merge_guest_config(common_config, cluster_common, guest, cluster_name, env)
          result[:guests] << merged
        end
      end

      puts JSON.pretty_generate(result)
    end

    private

    def collect_machine_names(clusters, global_common, env)
      names = []
      clusters.each do |cluster|
        cluster_name = cluster['name'] || 'default'
        cluster_common = cluster['common']
        cluster['guests']&.each do |guest|
          next unless guest['id'] && guest['enabled'] != false

          # Merge to get provider.name (same logic as process_cluster)
          merged = merge_guest_config(global_common, cluster_common, guest, cluster_name, env)
          machine_name = merged.dig('provider', 'name') || guest['id']
          names << machine_name
        end
      end
      names
    end

    def process_cluster(vagrant_config, cluster, global_common, all_machine_names, env)
      cluster_name = cluster['name'] || 'default'
      cluster_common = cluster['common']
      guests = cluster['guests'] || []

      log_info "Processing cluster: #{cluster_name}"

      guests.each do |guest|
        next if guest['enabled'] == false

        # Merge and apply conventions
        merged_guest = merge_guest_config(global_common, cluster_common, guest, cluster_name, env)
        define_guest(vagrant_config, merged_guest, all_machine_names, env)
      end
    end

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

    def define_guest(vagrant_config, guest, all_machine_names, env)
      guest_id = guest['id']
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
