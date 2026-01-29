# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures disk size using vagrant-disksize plugin
    # Reference: https://github.com/sprotheroe/vagrant-disksize
    #
    # Note: This plugin only works with VirtualBox provider and
    # requires the vagrant-disksize plugin to be installed.
    #
    # Example configuration:
    #   guests:
    #     - id: master
    #       disk_size: 50GB
    #       box:
    #         name: ubuntu/jammy64
    module Disksize
      class << self
        def configure(vm_config, guest)
          disk_size = guest['disk_size']
          return unless disk_size

          # vagrant-disksize expects size as string (e.g., '50GB')
          size = disk_size.to_s
          size = "#{size}GB" unless size =~ /[KMGT]B$/i

          vm_config.disksize.size = size
        end
      end
    end
  end
end
