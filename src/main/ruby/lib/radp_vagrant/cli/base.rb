# frozen_string_literal: true

module RadpVagrant
  module CLI
    # Base class for CLI commands
    # Provides common helpers for formatting and output
    class Base
      attr_reader :config_dir, :env_override, :merged_config

      def initialize(config_dir, env_override: nil)
        @config_dir = config_dir
        @env_override = env_override
        @merged_config = nil
      end

      def execute
        raise NotImplementedError, "Subclasses must implement #execute"
      end

      protected

      def load_config
        # Set environment override if specified
        ENV['RADP_VAGRANT_ENV'] = env_override if env_override

        @merged_config = RadpVagrant.build_merged_config(config_dir)
        unless @merged_config
          puts 'No vagrant configuration found'
          return false
        end
        true
      end

      def env
        @merged_config&.dig('env')
      end

      def clusters
        @merged_config&.dig('clusters') || []
      end

      # Format IP for display (compact view)
      # Returns dhcp, IP, or IP(+N) for multiple IPs
      def format_ip(network_config, type)
        return '-' unless network_config && network_config[type]
        cfg = network_config[type]
        return '-' unless cfg['enabled']
        ip = cfg['ip']
        return 'dhcp' if cfg['type'] == 'dhcp' || ip.nil?
        if ip.is_a?(Array)
          first_ip = ip.first.to_s
          ip.size > 1 ? "#{first_ip}(+#{ip.size - 1})" : first_ip
        else
          ip.to_s
        end
      end

      # Format IP for verbose display (full list)
      def format_ip_verbose(ip)
        return 'dhcp' if ip.nil?
        ip.is_a?(Array) ? ip.join(', ') : ip.to_s
      end

      # Format provisions for display
      def format_provisions(provisions)
        return [] unless provisions.is_a?(Array) && !provisions.empty?

        provisions.select { |p| p.is_a?(Hash) && p['enabled'] != false }.map do |p|
          phase = p['phase'] ? "[#{p['phase'].to_s.ljust(4)}]" : '[    ]'
          {
            phase: phase,
            name: p['name'] || 'unnamed',
            type: p['type'] || 'shell',
            run: p['run'] || 'once',
            privileged: p['privileged'] ? 'privileged' : ''
          }
        end
      rescue StandardError => e
        warn "Warning: Error parsing provisions: #{e.message}"
        []
      end

      # Format synced folders for display
      def format_synced_folders(synced_folders)
        return [] unless synced_folders

        result = []
        if synced_folders.is_a?(Hash)
          %w[basic nfs rsync smb].each do |folder_type|
            items = synced_folders[folder_type]
            next unless items

            list = items.is_a?(Array) ? items : [items]
            list.each do |item|
              next unless item.is_a?(Hash)
              next if item['enabled'] == false

              result << build_folder_entry(folder_type, item)
            end
          end
        elsif synced_folders.is_a?(Array)
          synced_folders.each do |item|
            next unless item.is_a?(Hash)
            next if item['enabled'] == false

            result << build_folder_entry(item['type'] || 'basic', item)
          end
        end
        result
      rescue StandardError => e
        warn "Warning: Error parsing synced-folders (#{synced_folders.class}): #{e.message}"
        warn e.backtrace.first(3).join("\n") if ENV['DEBUG']
        []
      end

      # Format triggers for display
      def format_triggers(triggers)
        return [] unless triggers.is_a?(Array) && !triggers.empty?

        triggers.select { |t| t.is_a?(Hash) && t['enabled'] != false }.map do |t|
          {
            name: t['name'] || 'unnamed',
            timing: t['on'] || 'before',
            actions: Array(t['action'] || [:up]).join(','),
            run_type: t['run-remote'] ? 'run-remote' : (t['run'] ? 'run' : '-')
          }
        end
      rescue StandardError => e
        warn "Warning: Error parsing triggers: #{e.message}"
        []
      end

      private

      def build_folder_entry(folder_type, item)
        extras = [
          item['owner'] ? "owner:#{item['owner']}" : nil,
          item['nfs-version'] ? "nfs-version:#{item['nfs-version']}" : nil,
          (item['bindfs'].is_a?(Hash) && item['bindfs']['enabled']) ? 'bindfs' : nil
        ].compact.join(' ')

        {
          type: folder_type,
          host: item['host'].to_s,
          guest: item['guest'].to_s,
          extras: extras
        }
      end
    end
  end
end
