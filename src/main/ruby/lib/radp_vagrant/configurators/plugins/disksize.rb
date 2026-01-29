# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      # Configurator for vagrant-disksize plugin
      # Reference: https://github.com/sprotheroe/vagrant-disksize
      #
      # This plugin allows resizing the primary disk of VirtualBox VMs.
      # Note: Only works with VirtualBox provider.
      #
      # Configuration is done at guest level via 'disk_size' option,
      # not through plugin options.
      #
      # Example:
      #   plugins:
      #     - name: vagrant-disksize
      #       required: true
      #
      #   clusters:
      #     - name: k8s
      #       guests:
      #         - id: master
      #           disk_size: 50GB
      #           box:
      #             name: ubuntu/jammy64
      class Disksize < Base
        class << self
          def plugin_name
            'vagrant-disksize'
          end

          def configure(_vagrant_config, _options)
            # No global configuration needed for vagrant-disksize
            # Disk size is configured per-guest via Configurators::Disksize
            nil
          end
        end
      end
    end
  end
end
