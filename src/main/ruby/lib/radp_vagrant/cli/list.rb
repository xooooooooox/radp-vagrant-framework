# frozen_string_literal: true

require 'open3'
require_relative 'base'

module RadpVagrant
  module CLI
    # List command - displays clusters and guests from configuration
    class List < Base
      attr_reader :verbose, :show_provisions, :show_synced_folders, :show_triggers, :filter,
                  :show_status, :vagrant_cwd

      def initialize(config_dir, env_override: nil, verbose: false,
                     show_provisions: false, show_synced_folders: false,
                     show_triggers: false, filter: nil,
                     show_status: false, vagrant_cwd: nil)
        super(config_dir, env_override: env_override)
        @verbose = verbose
        @show_provisions = show_provisions
        @show_synced_folders = show_synced_folders
        @show_triggers = show_triggers
        @filter = filter
        @show_status = show_status
        @vagrant_cwd = vagrant_cwd
      end

      def execute
        return 1 unless load_config

        @status_map = fetch_vagrant_status if show_status

        puts "Environment: #{env}"
        puts "Config Dir:  #{config_dir}"
        puts ''

        if clusters.empty?
          puts 'No clusters defined'
          return 0
        end

        # Collect all guests with filter
        all_guests = collect_filtered_guests

        if filter && all_guests.empty?
          puts "No guests matching '#{filter}'"
          return 0
        end

        # Determine display mode
        detail_mode = verbose || show_provisions || show_synced_folders || show_triggers

        if detail_mode
          display_detailed_view(all_guests)
        else
          display_compact_view
        end

        0
      end

      private

      def collect_filtered_guests
        all_guests = []
        clusters.each do |cluster|
          (cluster['guests'] || []).each do |guest|
            machine_name = guest.dig('provider', 'name') || guest['id']
            if filter.nil? || matches_filter?(guest, machine_name)
              all_guests << { cluster: cluster['name'], guest: guest, machine_name: machine_name }
            end
          end
        end
        all_guests
      end

      def matches_filter?(guest, machine_name)
        guest['id'] == filter || machine_name == filter || machine_name.include?(filter)
      end

      def display_compact_view
        total_guests = clusters.sum { |c| c['guests'].size }
        puts "Clusters: #{clusters.size} (#{total_guests} guests total)"
        puts ''

        clusters.each do |cluster|
          guests = cluster['guests'] || []

          # Filter if specified
          if filter
            guests = guests.select do |g|
              mn = g.dig('provider', 'name') || g['id']
              matches_filter?(g, mn)
            end
            next if guests.empty?
          end

          puts "  #{cluster['name']} (#{guests.size} guests)"

          guests.each_with_index do |guest, idx|
            display_compact_guest(guest, idx == guests.size - 1)
          end
          puts ''
        end
      end

      def display_compact_guest(guest, is_last)
        prefix = is_last ? '└──' : '├──'
        machine_name = guest.dig('provider', 'name') || guest['id']
        priv_ip = format_ip(guest['network'], 'private-network')
        pub_ip = format_ip(guest['network'], 'public-network')
        mem = guest.dig('provider', 'mem') || '-'
        cpus = guest.dig('provider', 'cpus') || '-'

        status_str = ''
        if @status_map
          state = @status_map[machine_name]
          status_str = "#{status_icon(state)} "
        end

        # Format: name  priv:IP  pub:IP  mem  cpu
        priv_str = "priv:#{priv_ip}".ljust(20)
        pub_str = pub_ip != '-' ? "pub:#{pub_ip}".ljust(18) : ''
        puts "    #{prefix} #{status_str}#{machine_name.ljust(28)} #{priv_str} #{pub_str} #{mem.to_s.rjust(5)}MB  #{cpus}CPU"
      end

      def display_detailed_view(all_guests)
        all_guests.each do |entry|
          guest = entry[:guest]
          machine_name = entry[:machine_name]

          puts "#{machine_name}:"

          display_basic_info(guest, machine_name) if verbose
          display_network(guest) if verbose
          display_synced_folders_section(guest) if verbose || show_synced_folders
          display_provisions_section(guest) if verbose || show_provisions
          display_triggers_section(guest) if verbose || show_triggers

          puts ''
        end
      end

      def display_basic_info(guest, machine_name = nil)
        if @status_map && machine_name
          state = @status_map[machine_name] || 'unknown'
          puts "  Status:   #{state}"
        end

        box = guest.dig('box', 'name') || '-'
        mem = guest.dig('provider', 'mem') || '-'
        cpus = guest.dig('provider', 'cpus') || '-'
        hostname = guest['hostname'] || '-'

        puts "  Box:      #{box}"
        puts "  Hostname: #{hostname}"
        puts "  Memory:   #{mem}MB"
        puts "  CPUs:     #{cpus}"
      end

      def display_network(guest)
        puts '  Network:'
        network = guest['network'] || {}

        priv = network['private-network']
        if priv && priv['enabled']
          ip_str = format_ip_verbose(priv['ip'])
          netmask = priv['netmask'] ? " (netmask: #{priv['netmask']})" : ''
          puts "    - private: #{ip_str}#{netmask}"
        end

        pub = network['public-network']
        if pub && pub['enabled']
          ip_str = format_ip_verbose(pub['ip'])
          bridge = pub['bridge'] ? " (bridge: #{Array(pub['bridge']).first})" : ''
          puts "    - public:  #{ip_str}#{bridge}"
        end

        ports = network['forwarded-ports']
        return unless ports.is_a?(Array) && !ports.empty?

        enabled_ports = ports.select { |p| p.is_a?(Hash) && p['enabled'] != false }
        return if enabled_ports.empty?

        port_strs = enabled_ports.map { |p| "#{p['guest']}->#{p['host']}" }
        puts "    - ports:   #{port_strs.join(', ')}"
      end

      def display_synced_folders_section(guest)
        folders = format_synced_folders(guest['synced-folders'])
        return if folders.empty?

        puts "  Synced Folders (#{folders.size}):"
        folders.each_with_index do |f, idx|
          prefix = idx == folders.size - 1 ? '└──' : '├──'
          extras = f[:extras].empty? ? '' : " (#{f[:extras]})"
          puts "    #{prefix} [#{f[:type].ljust(5)}] #{f[:host]} -> #{f[:guest]}#{extras}"
        end
      end

      def display_provisions_section(guest)
        provs = format_provisions(guest['provisions'])
        return if provs.empty?

        puts "  Provisions (#{provs.size}):"
        provs.each_with_index do |p, idx|
          prefix = idx == provs.size - 1 ? '└──' : '├──'
          priv = p[:privileged].empty? ? '' : " #{p[:privileged]}"
          puts "    #{prefix} #{p[:phase]} #{p[:name].ljust(30)} #{p[:type].ljust(6)} #{p[:run].ljust(6)}#{priv}"
        end
      end

      def display_triggers_section(guest)
        trigs = format_triggers(guest['triggers'])
        return if trigs.empty?

        puts "  Triggers (#{trigs.size}):"
        trigs.each_with_index do |t, idx|
          prefix = idx == trigs.size - 1 ? '└──' : '├──'
          puts "    #{prefix} #{t[:name].ljust(35)} #{t[:timing].ljust(6)} #{t[:actions].ljust(12)} #{t[:run_type]}"
        end
      end

      def fetch_vagrant_status
        return {} unless vagrant_cwd

        stdout, _stderr, status = Open3.capture3('vagrant', 'status', '--machine-readable', chdir: vagrant_cwd)
        unless status.success?
          warn 'Warning: vagrant status failed, status will not be shown'
          return {}
        end

        parse_vagrant_status(stdout)
      rescue Errno::ENOENT
        warn 'Warning: vagrant not found, status will not be shown'
        {}
      rescue StandardError => e
        warn "Warning: could not get vagrant status: #{e.message}"
        {}
      end

      def parse_vagrant_status(output)
        result = {}
        output.each_line do |line|
          fields = line.strip.split(',', 4)
          next unless fields.length >= 4

          target = fields[1]
          type = fields[2]
          data = fields[3]

          result[target] = data if type == 'state' && !target.empty?
        end
        result
      end

      def status_icon(state)
        if $stdout.tty?
          tty_status_icon(state)
        else
          text_status_badge(state)
        end
      end

      def tty_status_icon(state)
        case state
        when 'running'     then "\e[32m●\e[0m"
        when 'poweroff'    then "\e[31m●\e[0m"
        when 'aborted'     then "\e[31m●\e[0m"
        when 'saved'       then "\e[33m●\e[0m"
        when 'not_created' then "\e[90m○\e[0m"
        else                    "\e[90m?\e[0m"
        end
      end

      def text_status_badge(state)
        case state
        when 'running'     then '[up]  '
        when 'poweroff'    then '[off] '
        when 'aborted'     then '[err] '
        when 'saved'       then '[save]'
        when 'not_created' then '[--]  '
        else                    '[??]  '
        end
      end
    end
  end
end
