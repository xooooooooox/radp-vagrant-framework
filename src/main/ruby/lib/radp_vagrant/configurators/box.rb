# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM box settings
    module Box
      class << self
        def configure(vm_config, guest)
          box = guest['box']
          return unless box

          vm_config.vm.box = box['name'] if box['name']
          vm_config.vm.box_version = box['version'].to_s if box['version']
          vm_config.vm.box_check_update = box['check-update'] if box.key?('check-update')
        end
      end
    end
  end
end
