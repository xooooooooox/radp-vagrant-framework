#!/usr/bin/env ruby
# frozen_string_literal: true

# RADP Vagrant Framework - Vagrantfile Generator
# Generates a standalone Vagrantfile from YAML configuration for inspection
# Uses the same configurator logic as the main framework

require 'yaml'
require_relative 'config_loader'
require_relative 'config_merger'

module RadpVagrant
  # Mock objects that capture Vagrant configuration calls
  module MockVagrant
    # Captures method calls and stores them for code generation
    class CallRecorder
      attr_reader :calls

      def initialize(name = nil)
        @name = name
        @calls = []
      end

      def method_missing(method, *args, **kwargs, &block)
        call = { method: method, args: args, kwargs: kwargs }
        if block
          sub_recorder = CallRecorder.new
          block.call(sub_recorder)
          call[:block] = sub_recorder.calls
        end
        @calls << call
        self
      end

      def respond_to_missing?(*)
        true
      end
    end

    # Mock VM config
    class MockVmConfig
      attr_reader :vm

      def initialize
        @vm = CallRecorder.new('vm')
      end

      def hostmanager
        @hostmanager ||= CallRecorder.new('hostmanager')
      end
    end

    # Mock Vagrant config (top level)
    class MockVagrantConfig
      attr_reader :calls

      def initialize
        @calls = []
        @vm_defines = []
        @plugin_configs = {}
      end

      def vm
        @vm ||= MockVm.new(@vm_defines)
      end

      def trigger
        @trigger ||= MockTrigger.new(@calls)
      end

      def hostmanager
        @hostmanager ||= MockPluginConfig.new('hostmanager', @plugin_configs)
      end

      def vbguest
        @vbguest ||= MockPluginConfig.new('vbguest', @plugin_configs)
      end

      def proxy
        @proxy ||= MockPluginConfig.new('proxy', @plugin_configs)
      end

      def vm_defines
        @vm_defines
      end

      def plugin_configs
        @plugin_configs
      end

      def trigger_calls
        @calls
      end
    end

    class MockVm
      def initialize(defines)
        @defines = defines
      end

      def define(name, &block)
        vm_config = MockVmInstance.new(name)
        block.call(vm_config) if block
        @defines << vm_config
      end
    end

    class MockVmInstance
      attr_reader :name, :calls

      def initialize(name)
        @name = name
        @calls = []
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
        recorder = ProviderRecorder.new
        block.call(recorder) if block
        @calls << { type: :provider, provider_type: type, config: recorder.config }
      end

      def hostmanager
        @hostmanager ||= HostmanagerRecorder.new(@calls)
      end
    end

    class ProviderRecorder
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

    class HostmanagerRecorder
      def initialize(calls)
        @calls = calls
      end

      def aliases=(value)
        @calls << { type: :hostmanager_aliases, value: value }
      end

      def ip_resolver=(value)
        @calls << { type: :hostmanager_ip_resolver, value: value }
      end
    end

    class MockTrigger
      def initialize(calls)
        @calls = calls
      end

      def before(*actions, **kwargs, &block)
        record_trigger(:before, actions, kwargs, &block)
      end

      def after(*actions, **kwargs, &block)
        record_trigger(:after, actions, kwargs, &block)
      end

      private

      def record_trigger(timing, actions, kwargs, &block)
        trigger_config = TriggerConfigRecorder.new
        block.call(trigger_config) if block
        @calls << {
          type: :trigger,
          timing: timing,
          actions: actions,
          kwargs: kwargs,
          config: trigger_config.config
        }
      end
    end

    class TriggerConfigRecorder
      attr_reader :config

      def initialize
        @config = {}
      end

      def name=(value)
        @config[:name] = value
      end

      def info=(value)
        @config[:info] = value
      end

      def warn=(value)
        @config[:warn] = value
      end

      def on_error=(value)
        @config[:on_error] = value
      end

      def ignore=(value)
        @config[:ignore] = value
      end

      def only_on=(value)
        @config[:only_on] = value
      end

      def abort=(value)
        @config[:abort] = value
      end

      def run=(value)
        @config[:run] = value
      end

      def run_remote=(value)
        @config[:run_remote] = value
      end

      def ruby(&block)
        @config[:ruby] = block
      end
    end

    class MockPluginConfig
      def initialize(name, store)
        @name = name
        @store = store
        @store[@name] ||= {}
      end

      def method_missing(method, *args)
        if method.to_s.end_with?('=')
          attr = method.to_s.chomp('=')
          @store[@name][attr] = args.first
        else
          @store[@name][method.to_s]
        end
      end

      def respond_to_missing?(*)
        true
      end
    end
  end

  # Code generator that converts captured calls to Ruby code
  class CodeGenerator
    def initialize
      @indent = 0
    end

    def generate(mock_config)
      lines = []
      lines << header
      lines << ""
      lines << "Vagrant.require_version '>=1.6.0'"
      lines << ""
      lines << "Vagrant.configure('2') do |config|"
      @indent = 1

      # Plugin configurations
      generate_plugin_configs(lines, mock_config.plugin_configs)

      # Triggers (global)
      generate_triggers(lines, mock_config.trigger_calls)

      # VM defines
      mock_config.vm_defines.each do |vm|
        lines << ""
        generate_vm_define(lines, vm)
      end

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
        # Generated at: #{Time.now}
        #
        # This is a standalone Vagrantfile that does not require the framework.
      HEADER
    end

    def generate_plugin_configs(lines, configs)
      return if configs.empty?

      lines << ""
      lines << indent("# Plugin Configuration")

      configs.each do |plugin, settings|
        settings.each do |attr, value|
          lines << indent("config.#{plugin}.#{attr} = #{value.inspect}")
        end
      end
    end

    def generate_triggers(lines, trigger_calls)
      triggers = trigger_calls.select { |c| c[:type] == :trigger }
      return if triggers.empty?

      lines << ""
      lines << indent("# Global Triggers")
      triggers.each do |trigger|
        generate_trigger(lines, trigger, 'config')
      end
    end

    def generate_trigger(lines, trigger, var)
      timing = trigger[:timing]
      actions = trigger[:actions].map(&:inspect).join(', ')
      config = trigger[:config]

      type_opt = trigger[:kwargs][:type] ? ", type: #{trigger[:kwargs][:type].inspect}" : ""
      lines << indent("#{var}.trigger.#{timing} #{actions}#{type_opt} do |t|")
      @indent += 1

      lines << indent("t.name = #{config[:name].inspect}") if config[:name]
      lines << indent("t.info = #{config[:info].inspect}") if config[:info]
      lines << indent("t.warn = #{config[:warn].inspect}") if config[:warn]
      lines << indent("t.on_error = #{config[:on_error].inspect}") if config[:on_error]
      lines << indent("t.only_on = #{config[:only_on].inspect}") if config[:only_on]

      if config[:run]
        lines << indent("t.run = #{config[:run].inspect}")
      elsif config[:run_remote]
        lines << indent("t.run_remote = #{config[:run_remote].inspect}")
      end

      @indent -= 1
      lines << indent("end")
    end

    def generate_vm_define(lines, vm)
      var = safe_var(vm.name)
      lines << indent("# Guest: #{vm.name}")
      lines << indent("config.vm.define '#{vm.name}' do |#{var}|")
      @indent += 1

      vm.calls.each do |call|
        case call[:type]
        when :box
          lines << indent("#{var}.vm.box = #{call[:value].inspect}")
        when :box_version
          lines << indent("#{var}.vm.box_version = #{call[:value].inspect}")
        when :box_check_update
          lines << indent("#{var}.vm.box_check_update = #{call[:value].inspect}")
        when :hostname
          lines << indent("#{var}.vm.hostname = #{call[:value].inspect}")
        when :network
          generate_network(lines, var, call)
        when :synced_folder
          generate_synced_folder(lines, var, call)
        when :provision
          generate_provision(lines, var, call)
        when :provider
          generate_provider(lines, var, call)
        when :hostmanager_aliases
          lines << indent("#{var}.hostmanager.aliases = #{call[:value].inspect}")
        end
      end

      @indent -= 1
      lines << indent("end")
    end

    def generate_network(lines, var, call)
      opts = call[:options].map { |k, v| "#{k}: #{v.inspect}" }.join(', ')
      lines << indent("#{var}.vm.network '#{call[:network_type]}', #{opts}")
    end

    def generate_synced_folder(lines, var, call)
      opts = call[:options].map { |k, v| "#{k}: #{v.inspect}" }.join(', ')
      opts_str = opts.empty? ? "" : ", #{opts}"
      lines << indent("#{var}.vm.synced_folder '#{call[:host]}', '#{call[:guest]}'#{opts_str}")
    end

    def generate_provision(lines, var, call)
      opts = call[:options].dup
      inline = opts.delete(:inline)

      if inline
        opts_str = opts.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')
        opts_prefix = opts_str.empty? ? "" : "#{opts_str}, "
        lines << indent("#{var}.vm.provision '#{call[:provision_type]}', #{opts_prefix}inline: <<~SHELL")
        inline.each_line { |l| lines << indent("  #{l.rstrip}") }
        lines << indent("SHELL")
      else
        opts_str = opts.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')
        lines << indent("#{var}.vm.provision '#{call[:provision_type]}', #{opts_str}")
      end
    end

    def generate_provider(lines, var, call)
      lines << ""
      lines << indent("#{var}.vm.provider '#{call[:provider_type]}' do |vb|")
      @indent += 1

      config = call[:config]
      lines << indent("vb.name = #{config[:name].inspect}") if config[:name]
      lines << indent("vb.memory = #{config[:memory]}") if config[:memory]
      lines << indent("vb.cpus = #{config[:cpus]}") if config[:cpus]
      lines << indent("vb.gui = #{config[:gui]}") if config.key?(:gui)

      config[:customize]&.each do |cmd|
        lines << indent("vb.customize #{cmd.inspect}")
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
  end

  # Generator that uses the actual configurators with mock objects
  class Generator
    def initialize(config_path)
      @config_path = config_path
      @config = ConfigLoader.load(config_path)
    end

    def generate
      # Load configurators
      require_relative 'configurators/box'
      require_relative 'configurators/provider'
      require_relative 'configurators/network'
      require_relative 'configurators/synced_folder'
      require_relative 'configurators/provision'
      require_relative 'configurators/trigger'
      require_relative 'configurators/plugin'

      # Create mock config
      mock_config = MockVagrant::MockVagrantConfig.new

      # Configure using the same logic as the main framework
      vagrant_section = @config.dig('radp', 'extend', 'vagrant')
      return "# No vagrant configuration found" unless vagrant_section

      # Configure plugins
      Configurators::Plugin.configure(mock_config, vagrant_section['plugins'])

      # Process clusters
      common_config = vagrant_section.dig('config', 'common')
      clusters = vagrant_section.dig('config', 'clusters') || []

      # Collect all guest IDs
      all_guest_ids = clusters.flat_map { |c| c['guests']&.map { |g| g['id'] } || [] }

      clusters.each do |cluster|
        process_cluster(mock_config, cluster, common_config, all_guest_ids)
      end

      # Generate code from captured calls
      CodeGenerator.new.generate(mock_config)
    end

    private

    def process_cluster(mock_config, cluster, global_common, all_guest_ids)
      cluster_name = cluster['name'] || 'default'
      cluster_common = cluster['common']
      guests = cluster['guests'] || []

      guests.each do |guest|
        next if guest['enabled'] == false

        merged = ConfigMerger.merge_guest_config(global_common, cluster_common, guest)
        merged['cluster-name'] = cluster_name
        merged['provider'] ||= {}
        merged['provider']['group-id'] ||= cluster_name

        define_guest(mock_config, merged, all_guest_ids)
      end
    end

    def define_guest(mock_config, guest, all_guest_ids)
      guest_id = guest['id']

      mock_config.vm.define(guest_id) do |vm_config|
        Configurators::Box.configure(vm_config, guest)
        Configurators::Provider.configure(vm_config, guest)
        Configurators::Network.configure(vm_config, guest)
        Configurators::SyncedFolder.configure(vm_config, guest)
        Configurators::Provision.configure(vm_config, guest)
        Configurators::Trigger.configure(mock_config, guest, all_guest_ids: all_guest_ids)
      end
    end
  end
end

# CLI execution
if __FILE__ == $PROGRAM_NAME
  config_path = ARGV[0] || File.join(File.dirname(__FILE__), '..', '..', 'config', 'vagrant.yaml')

  unless File.exist?(config_path)
    warn "Error: Configuration file not found: #{config_path}"
    warn "Usage: ruby #{$PROGRAM_NAME} [config_path]"
    exit 1
  end

  generator = RadpVagrant::Generator.new(config_path)
  puts generator.generate
end
