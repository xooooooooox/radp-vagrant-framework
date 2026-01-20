# frozen_string_literal: true

# RADP Vagrant Framework - Vagrantfile Generator
# Generates a standalone Vagrantfile from YAML configuration
# Reuses the same configuration logic as the main framework

require_relative 'config_loader'
require_relative 'config_merger'
require_relative 'configurators/box'
require_relative 'configurators/provider'
require_relative 'configurators/network'
require_relative 'configurators/hostmanager'
require_relative 'configurators/synced_folder'
require_relative 'configurators/provision'
require_relative 'configurators/trigger'
require_relative 'configurators/plugin'

module RadpVagrant
  # Mock objects that capture Vagrant configuration calls
  module MockVagrant
    # Mock plugin config that captures settings
    class MockPluginConfig
      attr_reader :settings

      def initialize(name)
        @name = name
        @settings = {}
      end

      def method_missing(method, *args)
        if method.to_s.end_with?('=')
          attr = method.to_s.chomp('=')
          @settings[attr] = args.first
        else
          @settings[method.to_s]
        end
      end

      def respond_to_missing?(*)
        true
      end
    end

    # Mock provider recorder
    class MockProvider
      attr_reader :config

      def initialize
        @config = {}
      end

      def name=(value)
        @config[:name] = value
      end

      def memory=(value)
        @config[:memory] = value
      end

      def cpus=(value)
        @config[:cpus] = value
      end

      def gui=(value)
        @config[:gui] = value
      end

      def customize(args)
        @config[:customize] ||= []
        @config[:customize] << args
      end
    end

    # Mock hostmanager for per-guest settings
    class MockHostmanager
      attr_reader :config

      def initialize
        @config = {}
      end

      def aliases=(value)
        @config[:aliases] = value
      end

      def ip_resolver=(value)
        @config[:ip_resolver] = value
      end
    end

    # Mock VM instance (per guest)
    class MockVmInstance
      attr_reader :name, :calls, :hostmanager_config

      def initialize(name)
        @name = name
        @calls = []
        @hostmanager = MockHostmanager.new
      end

      def vm
        self
      end

      def box=(value)
        @calls << { type: :box, value: value }
      end

      def box_version=(value)
        @calls << { type: :box_version, value: value }
      end

      def box_check_update=(value)
        @calls << { type: :box_check_update, value: value }
      end

      def hostname=(value)
        @calls << { type: :hostname, value: value }
      end

      def network(type, **options)
        @calls << { type: :network, network_type: type, options: options }
      end

      def synced_folder(host, guest, **options)
        @calls << { type: :synced_folder, host: host, guest: guest, options: options }
      end

      def provision(type, **options)
        @calls << { type: :provision, provision_type: type, options: options }
      end

      def provider(type, &block)
        recorder = MockProvider.new
        block.call(recorder) if block
        @calls << { type: :provider, provider_type: type, config: recorder.config }
      end

      def hostmanager
        @hostmanager
      end

      def hostmanager_config
        @hostmanager.config
      end
    end

    # Mock trigger config recorder
    class MockTriggerConfig
      attr_reader :config

      def initialize
        @config = {}
      end

      %i[name info warn on_error ignore only_on abort run run_remote].each do |attr|
        define_method("#{attr}=") do |value|
          @config[attr] = value
        end
      end

      def ruby(&block)
        @config[:ruby] = block
      end
    end

    # Mock trigger that captures before/after calls
    class MockTrigger
      attr_reader :calls

      def initialize
        @calls = []
      end

      def before(*actions, **kwargs, &block)
        record_trigger(:before, actions, kwargs, &block)
      end

      def after(*actions, **kwargs, &block)
        record_trigger(:after, actions, kwargs, &block)
      end

      private

      def record_trigger(timing, actions, kwargs, &block)
        config = MockTriggerConfig.new
        block.call(config) if block
        @calls << {
          type: :trigger,
          timing: timing,
          actions: actions,
          kwargs: kwargs,
          config: config.config
        }
      end
    end

    # Mock VM that records define calls
    class MockVm
      attr_reader :defines

      def initialize
        @defines = []
      end

      def define(name, &block)
        vm_instance = MockVmInstance.new(name)
        block.call(vm_instance) if block
        @defines << vm_instance
      end
    end

    # Top-level mock Vagrant config
    class MockVagrantConfig
      attr_reader :vm, :trigger, :plugin_configs

      def initialize
        @vm = MockVm.new
        @trigger = MockTrigger.new
        @plugin_configs = {}
      end

      def hostmanager
        @plugin_configs['hostmanager'] ||= MockPluginConfig.new('hostmanager')
      end

      def vbguest
        @plugin_configs['vbguest'] ||= MockPluginConfig.new('vbguest')
      end

      def proxy
        @plugin_configs['proxy'] ||= MockPluginConfig.new('proxy')
      end

      def bindfs
        @plugin_configs['bindfs'] ||= MockPluginConfig.new('bindfs')
      end

      # Generic plugin config accessor
      def method_missing(method, *args)
        @plugin_configs[method.to_s] ||= MockPluginConfig.new(method.to_s)
      end

      def respond_to_missing?(*)
        true
      end
    end
  end

  # Converts captured mock calls to Ruby code
  class CodeGenerator
    def initialize(merged_config, mock_config)
      @merged_config = merged_config
      @mock_config = mock_config
      @indent = 0
    end

    def generate
      lines = []
      lines << header
      lines << ""
      lines << "Vagrant.require_version '>= 2.0.0'"
      lines << ""
      lines << "Vagrant.configure('2') do |config|"
      @indent = 1

      generate_plugin_configs(lines)
      generate_vm_defines(lines)

      @indent = 0
      lines << "end"
      lines.join("\n")
    end

    private

    def header
      <<~HEADER.chomp
        # -*- mode: ruby -*-
        # vi: set ft=ruby :
        #
        # Generated by RADP Vagrant Framework
        # Source: #{@merged_config['config_dir']}
        # Environment: #{@merged_config['env']}
        # Generated at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        #
        # This is a standalone Vagrantfile that does not require the framework.
        # It shows the final configuration that would be applied to Vagrant.
      HEADER
    end

    def generate_plugin_configs(lines)
      return if @mock_config.plugin_configs.empty?

      lines << ""
      lines << indent("# ===================")
      lines << indent("# Plugin Configuration")
      lines << indent("# ===================")

      @mock_config.plugin_configs.each do |plugin, config|
        next if config.settings.empty?

        lines << ""
        lines << indent("# #{plugin}")
        config.settings.each do |attr, value|
          lines << indent("config.#{plugin}.#{attr} = #{ruby_literal(value)}")
        end
      end
    end

    def generate_vm_defines(lines)
      @mock_config.vm.defines.each_with_index do |vm, idx|
        lines << ""
        lines << indent("# " + "=" * 50)
        lines << indent("# Guest: #{vm.name}")
        lines << indent("# " + "=" * 50)

        var = safe_var(vm.name)
        lines << indent("config.vm.define '#{vm.name}' do |#{var}|")
        @indent += 1

        generate_vm_calls(lines, var, vm)
        generate_vm_triggers(lines, var, vm)

        @indent -= 1
        lines << indent("end")
      end
    end

    def generate_vm_calls(lines, var, vm)
      vm.calls.each do |call|
        case call[:type]
        when :box
          lines << indent("#{var}.vm.box = #{ruby_literal(call[:value])}")
        when :box_version
          lines << indent("#{var}.vm.box_version = #{ruby_literal(call[:value])}")
        when :box_check_update
          lines << indent("#{var}.vm.box_check_update = #{call[:value]}")
        when :hostname
          lines << indent("#{var}.vm.hostname = #{ruby_literal(call[:value])}")
        when :network
          generate_network(lines, var, call)
        when :synced_folder
          generate_synced_folder(lines, var, call)
        when :provision
          generate_provision(lines, var, call)
        when :provider
          generate_provider(lines, var, call)
        end
      end

      # Hostmanager per-guest config
      generate_hostmanager(lines, var, vm.hostmanager_config)
    end

    def generate_network(lines, var, call)
      opts = format_options(call[:options])
      if opts.empty?
        lines << indent("#{var}.vm.network '#{call[:network_type]}'")
      else
        lines << indent("#{var}.vm.network '#{call[:network_type]}', #{opts}")
      end
    end

    def generate_synced_folder(lines, var, call)
      opts = format_options(call[:options])
      opts_str = opts.empty? ? "" : ", #{opts}"
      lines << indent("#{var}.vm.synced_folder #{ruby_literal(call[:host])}, #{ruby_literal(call[:guest])}#{opts_str}")
    end

    def generate_provision(lines, var, call)
      opts = call[:options].dup
      inline = opts.delete(:inline)
      name = opts[:name]

      if inline && inline.include?("\n")
        # Multi-line inline script
        opts_str = format_options(opts)
        opts_prefix = opts_str.empty? ? "" : "#{opts_str}, "
        lines << indent("#{var}.vm.provision '#{call[:provision_type]}', #{opts_prefix}inline: <<~SHELL")
        @indent += 1
        inline.each_line { |l| lines << indent(l.rstrip) }
        @indent -= 1
        lines << indent("SHELL")
      else
        # Single line or path-based
        opts[:inline] = inline if inline
        opts_str = format_options(opts)
        lines << indent("#{var}.vm.provision '#{call[:provision_type]}', #{opts_str}")
      end
    end

    def generate_provider(lines, var, call)
      config = call[:config]
      return if config.empty?

      lines << ""
      lines << indent("#{var}.vm.provider '#{call[:provider_type]}' do |vb|")
      @indent += 1

      lines << indent("vb.name = #{ruby_literal(config[:name])}") if config[:name]
      lines << indent("vb.memory = #{config[:memory]}") if config[:memory]
      lines << indent("vb.cpus = #{config[:cpus]}") if config[:cpus]
      lines << indent("vb.gui = #{config[:gui]}") if config.key?(:gui)

      config[:customize]&.each do |cmd|
        lines << indent("vb.customize #{ruby_literal(cmd)}")
      end

      @indent -= 1
      lines << indent("end")
    end

    def generate_hostmanager(lines, var, config)
      return if config.empty?

      lines << ""
      lines << indent("# Hostmanager per-guest settings")
      lines << indent("#{var}.hostmanager.aliases = #{ruby_literal(config[:aliases])}") if config[:aliases]

      if config[:ip_resolver]
        lines << indent("# Note: ip_resolver contains a proc, shown as placeholder")
        lines << indent("# #{var}.hostmanager.ip_resolver = proc { |vm, resolving_vm| ... }")
      end
    end

    def generate_vm_triggers(lines, var, vm)
      # Triggers are recorded at the config level, filter by machine name
      triggers = @mock_config.trigger.calls.select do |t|
        only_on = t[:config][:only_on]
        only_on.nil? || only_on.include?(vm.name)
      end

      return if triggers.empty?

      lines << ""
      lines << indent("# Triggers")
      triggers.each do |trigger|
        generate_trigger(lines, 'config', trigger)
      end
    end

    def generate_trigger(lines, var, trigger)
      timing = trigger[:timing]
      actions = trigger[:actions].map { |a| ":#{a}" }.join(', ')
      config = trigger[:config]

      type_opt = trigger[:kwargs][:type] ? ", type: :#{trigger[:kwargs][:type]}" : ""
      lines << indent("#{var}.trigger.#{timing} #{actions}#{type_opt} do |t|")
      @indent += 1

      lines << indent("t.name = #{ruby_literal(config[:name])}") if config[:name]
      lines << indent("t.info = #{ruby_literal(config[:info])}") if config[:info]
      lines << indent("t.warn = #{ruby_literal(config[:warn])}") if config[:warn]
      lines << indent("t.on_error = :#{config[:on_error]}") if config[:on_error]
      lines << indent("t.only_on = #{ruby_literal(config[:only_on])}") if config[:only_on]

      if config[:run]
        lines << indent("t.run = #{ruby_literal(config[:run])}")
      elsif config[:run_remote]
        lines << indent("t.run_remote = #{ruby_literal(config[:run_remote])}")
      end

      @indent -= 1
      lines << indent("end")
    end

    def indent(str)
      '  ' * @indent + str
    end

    def safe_var(name)
      name.to_s.gsub(/[^a-zA-Z0-9_]/, '_')
    end

    def ruby_literal(value)
      case value
      when String
        value.inspect
      when Symbol
        ":#{value}"
      when Array
        "[#{value.map { |v| ruby_literal(v) }.join(', ')}]"
      when Hash
        pairs = value.map { |k, v| "#{ruby_key(k)} => #{ruby_literal(v)}" }
        "{ #{pairs.join(', ')} }"
      when NilClass
        'nil'
      when TrueClass, FalseClass
        value.to_s
      else
        value.inspect
      end
    end

    def ruby_key(key)
      case key
      when Symbol
        ":#{key}"
      when String
        key.inspect
      else
        key.inspect
      end
    end

    def format_options(opts)
      return "" if opts.nil? || opts.empty?

      opts.map { |k, v| "#{k}: #{ruby_literal(v)}" }.join(', ')
    end
  end

  # Generator that uses the actual configurators with mock objects
  # Reuses build_merged_config for consistency
  class Generator
    def initialize(config_dir)
      @config_dir = config_dir
    end

    def generate
      # Reuse the same merged config logic as the main framework
      merged = RadpVagrant.build_merged_config(@config_dir)
      return "# No vagrant configuration found" unless merged

      # Create mock config to capture calls
      mock_config = MockVagrant::MockVagrantConfig.new

      # Configure plugins (same as main framework)
      Configurators::Plugin.configure(mock_config, merged['plugins'])

      # Collect all machine names (same as main framework)
      all_machine_names = merged['clusters'].flat_map do |cluster|
        cluster['guests'].map { |g| g.dig('provider', 'name') || g['id'] }
      end

      # Process each cluster (same as main framework)
      merged['clusters'].each do |cluster|
        cluster['guests'].each do |guest|
          define_guest(mock_config, guest, all_machine_names)
        end
      end

      # Generate Ruby code from captured calls
      CodeGenerator.new(merged, mock_config).generate
    end

    private

    # Same logic as RadpVagrant.define_guest
    def define_guest(mock_config, guest, all_machine_names)
      env = guest['_env']
      # Use provider.name as machine name (same convention as main framework)
      machine_name = guest.dig('provider', 'name') || guest['id']

      mock_config.vm.define(machine_name) do |vm_config|
        Configurators::Box.configure(vm_config, guest)
        Configurators::Provider.configure(vm_config, guest)
        Configurators::Network.configure(vm_config, guest, env: env)
        Configurators::Hostmanager.configure(vm_config, guest)
        Configurators::SyncedFolder.configure(vm_config, guest)
        Configurators::Provision.configure(vm_config, guest)
        Configurators::Trigger.configure(mock_config, guest, all_machine_names: all_machine_names)
      end
    end
  end
end

# CLI execution
if __FILE__ == $PROGRAM_NAME
  require_relative '../radp_vagrant'

  config_dir = ARGV[0] || File.join(File.dirname(__FILE__), '..', '..', 'config')

  unless File.directory?(config_dir)
    warn "Error: Configuration directory not found: #{config_dir}"
    warn "Usage: ruby #{$PROGRAM_NAME} [config_dir]"
    exit 1
  end

  generator = RadpVagrant::Generator.new(config_dir)
  puts generator.generate
end
