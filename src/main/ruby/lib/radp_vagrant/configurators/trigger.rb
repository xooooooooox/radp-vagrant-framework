# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM triggers (before/after actions)
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
          # cycle: before or after
          cycle = trigger['cycle'] || 'before'

          # type: actions, hooks, commands (use strings)
          trigger_type = trigger['type']&.to_s&.delete_prefix(':') || 'actions'

          # Get actions based on type
          actions = parse_actions(trigger, trigger_type)

          # Handle only-on filter
          only_on = parse_only_on(trigger['only-on'], guest_id, all_guest_ids)

          # Skip if only-on doesn't match this guest
          return if only_on == :skip

          trigger_method = vagrant_config.trigger.method(cycle.to_sym)
          trigger_method.call(*actions) do |t|
            t.name = trigger['name'] if trigger['name']
            t.info = trigger['desc'] || trigger['info'] if trigger['desc'] || trigger['info']
            t.warn = trigger['warn'] if trigger['warn']
            t.on_error = trigger['on-error']&.to_sym if trigger['on-error']
            t.ignore = trigger['ignore'] if trigger.key?('ignore')
            t.only_on = only_on if only_on

            configure_run(t, trigger)
          end
        end

        def parse_actions(trigger, trigger_type)
          actions = trigger['action'] || [:up]

          actions.map do |action|
            # Handle both string and symbol formats
            action.is_a?(String) ? action.delete_prefix(':').to_sym : action
          end
        end

        def parse_only_on(only_on, guest_id, all_guest_ids)
          return nil unless only_on
          return only_on if only_on.is_a?(Array) && only_on.none? { |o| o.is_a?(String) && o.start_with?('/') }

          # Handle regex patterns like '/k8s-.*/'
          matched_ids = []
          only_on.each do |pattern|
            if pattern.is_a?(String) && pattern.start_with?('/') && pattern.end_with?('/')
              # Extract regex pattern
              regex = Regexp.new(pattern[1..-2])
              matched_ids.concat(all_guest_ids.select { |id| id =~ regex })
            else
              matched_ids << pattern
            end
          end

          # If this guest isn't in the matched list, skip the trigger for this guest
          return :skip if guest_id && !matched_ids.include?(guest_id)

          matched_ids.empty? ? nil : matched_ids
        end

        def configure_run(trigger, config)
          run_config = config['run']
          run_remote_config = config['run_remote']

          if run_config
            if run_config['inline']
              trigger.run = { inline: run_config['inline'] }
            elsif run_config['path']
              trigger.run = { path: run_config['path'] }
            end
          elsif run_remote_config
            if run_remote_config['inline']
              trigger.run_remote = { inline: run_remote_config['inline'] }
            elsif run_remote_config['path']
              trigger.run_remote = { path: run_remote_config['path'] }
            end
          elsif config['ruby']
            trigger.ruby do |_env, _machine|
              eval(config['ruby'])
            end
          end
        end
      end
    end
  end
end
