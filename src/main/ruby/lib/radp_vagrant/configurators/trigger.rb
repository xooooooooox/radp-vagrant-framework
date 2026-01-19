# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM triggers (before/after actions)
    # Reference: https://developer.hashicorp.com/vagrant/docs/triggers/configuration
    module Trigger
      class << self
        def configure(vagrant_config, guest, all_guest_ids: [])
          triggers = guest['triggers']
          return unless triggers

          triggers.each do |trigger|
            next unless trigger['enabled']

            configure_trigger(vagrant_config, trigger, guest['id'], all_guest_ids)
          end
        end

        private

        def configure_trigger(vagrant_config, trigger, guest_id, all_guest_ids)
          # on: before or after (renamed from cycle)
          timing = trigger['on'] || 'before'

          # type: action, command, hook (scope of trigger)
          # - :action - fires around Vagrant actions
          # - :command - fires around Vagrant commands
          # - :hook - fires around Vagrant hooks
          trigger_type = normalize_type(trigger['type'])

          # action: which actions/commands to trigger on
          actions = parse_actions(trigger['action'])

          # Handle only-on filter
          only_on = parse_only_on(trigger['only-on'], guest_id, all_guest_ids)

          # Skip if only-on doesn't match this guest
          return if only_on == :skip

          # Call the appropriate trigger method
          trigger_method = vagrant_config.trigger.method(timing.to_sym)
          trigger_method.call(*actions, type: trigger_type) do |t|
            t.name = trigger['name'] if trigger['name']
            t.info = trigger['desc'] || trigger['info'] if trigger['desc'] || trigger['info']
            t.warn = trigger['warn'] if trigger['warn']
            t.on_error = normalize_symbol(trigger['on-error']) if trigger['on-error']
            t.ignore = parse_actions(trigger['ignore']) if trigger['ignore']
            t.only_on = only_on if only_on
            t.abort = trigger['abort'] if trigger.key?('abort')

            configure_run(t, trigger)
          end
        end

        def normalize_type(type)
          return :action unless type

          type_str = type.to_s.delete_prefix(':')
          case type_str
          when 'action', 'actions' then :action
          when 'command', 'commands' then :command
          when 'hook', 'hooks' then :hook
          else :action
          end
        end

        def normalize_symbol(value)
          return nil unless value

          value.to_s.delete_prefix(':').to_sym
        end

        def parse_actions(actions)
          return [:up] unless actions

          Array(actions).map do |action|
            # Handle both string and symbol formats (:up, 'up', ':up')
            action.to_s.delete_prefix(':').to_sym
          end
        end

        def parse_only_on(only_on, guest_id, all_guest_ids)
          return nil unless only_on

          patterns = Array(only_on)

          # Check if any pattern is a regex string
          has_regex = patterns.any? { |p| p.is_a?(String) && p.start_with?('/') && p.end_with?('/') }

          return patterns unless has_regex

          # Expand regex patterns to matching guest IDs
          matched_ids = []
          patterns.each do |pattern|
            if pattern.is_a?(String) && pattern.start_with?('/') && pattern.end_with?('/')
              regex = Regexp.new(pattern[1..-2])
              matched_ids.concat(all_guest_ids.select { |id| id =~ regex })
            else
              matched_ids << pattern
            end
          end

          # If this guest isn't in the matched list, skip
          return :skip if guest_id && !matched_ids.include?(guest_id)

          matched_ids.empty? ? nil : matched_ids
        end

        def configure_run(trigger, config)
          run_config = config['run']
          run_remote_config = config['run-remote'] || config['run_remote']

          if run_config.is_a?(Hash)
            opts = {}
            opts[:inline] = run_config['inline'] if run_config['inline']
            opts[:path] = run_config['path'] if run_config['path']
            opts[:args] = run_config['args'] if run_config['args']
            trigger.run = opts unless opts.empty?
          elsif run_remote_config.is_a?(Hash)
            opts = {}
            opts[:inline] = run_remote_config['inline'] if run_remote_config['inline']
            opts[:path] = run_remote_config['path'] if run_remote_config['path']
            opts[:args] = run_remote_config['args'] if run_remote_config['args']
            trigger.run_remote = opts unless opts.empty?
          elsif config['ruby']
            trigger.ruby do |env, machine|
              eval(config['ruby'])
            end
          end
        end
      end
    end
  end
end
