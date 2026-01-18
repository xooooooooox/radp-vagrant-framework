# frozen_string_literal: true

# RADP Vagrant Framework
# A YAML-driven framework for managing multi-machine Vagrant environments

require_relative 'radp_vagrant/config_loader'
require_relative 'radp_vagrant/config_merger'
require_relative 'radp_vagrant/configurators/box'
require_relative 'radp_vagrant/configurators/provider'
require_relative 'radp_vagrant/configurators/network'
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
    def configure(vagrant_config, config_path)
      puts BANNER
      log_info "Loading configuration from: #{config_path}"

      config = ConfigLoader.load(config_path)
      vagrant_section = config.dig('radp', 'extend', 'vagrant')

      return log_warn('No vagrant configuration found') unless vagrant_section

      # Configure plugins first
      Configurators::Plugin.configure(vagrant_config, vagrant_section['plugins'])

      # Get configuration sections
      common_config = vagrant_section.dig('config', 'common')
      clusters = vagrant_section.dig('config', 'clusters') || []

      # Collect all guest IDs for trigger only-on matching
      all_guest_ids = collect_guest_ids(clusters)

      # Process each cluster
      clusters.each do |cluster|
        process_cluster(vagrant_config, cluster, common_config, all_guest_ids)
      end

      log_info 'Configuration complete'
    end

    private

    def collect_guest_ids(clusters)
      ids = []
      clusters.each do |cluster|
        cluster['guests']&.each do |guest|
          ids << guest['id'] if guest['id']
        end
      end
      ids
    end

    def process_cluster(vagrant_config, cluster, global_common, all_guest_ids)
      cluster_name = cluster['name'] || 'default'
      cluster_common = cluster['common']
      guests = cluster['guests'] || []

      log_info "Processing cluster: #{cluster_name}"

      guests.each do |guest|
        next if guest['enabled'] == false

        # Merge configuration: global -> cluster -> guest
        merged_guest = ConfigMerger.merge_guest_config(global_common, cluster_common, guest)

        # Inject cluster context
        merged_guest['cluster-name'] = cluster_name
        merged_guest['provider'] ||= {}
        merged_guest['provider']['group-id'] ||= cluster_name

        define_guest(vagrant_config, merged_guest, all_guest_ids)
      end
    end

    def define_guest(vagrant_config, guest, all_guest_ids)
      guest_id = guest['id']
      log_info "  Defining guest: #{guest_id}"

      vagrant_config.vm.define guest_id do |vm_config|
        Configurators::Box.configure(vm_config, guest)
        Configurators::Provider.configure(vm_config, guest)
        Configurators::Network.configure(vm_config, guest)
        Configurators::SyncedFolder.configure(vm_config, guest)
        Configurators::Provision.configure(vm_config, guest)
        Configurators::Trigger.configure(vagrant_config, guest, all_guest_ids: all_guest_ids)
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
