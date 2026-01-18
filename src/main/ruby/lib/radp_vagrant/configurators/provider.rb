# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM provider (VirtualBox, VMware, etc.)
    module Provider
      # Extensible provider registry
      CONFIGURATORS = {
        'virtualbox' => lambda { |provider, opts|
          provider.name = opts['name'] if opts['name']
          provider.memory = opts['mem'] || 2048
          provider.cpus = opts['cpus'] || 2
          provider.gui = opts['gui'] || false

          if opts['group-id']
            provider.customize ['modifyvm', :id, '--groups', "/#{opts['group-id']}"]
          end

          opts['customize']&.each do |cmd|
            provider.customize cmd
          end
        }
        # Future extensions:
        # 'vmware_desktop' => ->(provider, opts) { ... },
        # 'docker' => ->(provider, opts) { ... }
      }.freeze

      class << self
        def configure(vm_config, guest)
          provider_config = guest['provider']
          return unless provider_config

          provider_type = provider_config['type'] || 'virtualbox'
          configurator = CONFIGURATORS[provider_type]

          return unless configurator

          vm_config.vm.provider provider_type do |provider|
            configurator.call(provider, provider_config)
          end
        end

        # Register a new provider configurator
        def register(provider_type, &block)
          CONFIGURATORS[provider_type] = block
        end
      end
    end
  end
end
