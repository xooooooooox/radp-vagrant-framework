# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM synced folders (basic, nfs, rsync, smb)
    module SyncedFolder
      class << self
        def configure(vm_config, guest)
          folders = guest['synced-folders']
          return unless folders

          folders.each do |folder|
            next unless folder['enabled']

            configure_folder(vm_config, folder)
          end
        end

        private

        def configure_folder(vm_config, folder)
          host_path = folder['host']
          guest_path = folder['guest']
          folder_type = folder['type'] || 'basic'

          return unless host_path && guest_path

          options = build_options(folder, folder_type)
          vm_config.vm.synced_folder host_path, guest_path, **options
        end

        def build_options(folder, folder_type)
          options = { create: folder['create'] || false }

          case folder_type
          when 'basic'
            build_basic_options(options, folder)
          when 'nfs'
            build_nfs_options(options, folder)
          when 'rsync'
            build_rsync_options(options, folder)
          when 'smb'
            build_smb_options(options, folder)
          end

          options
        end

        def build_basic_options(options, folder)
          options[:owner] = folder['owner'] if folder['owner']
          options[:group] = folder['group'] if folder['group']
          options[:mount_options] = folder['mount-options'] if folder['mount-options']
        end

        def build_nfs_options(options, folder)
          options[:type] = 'nfs'
          options[:nfs_version] = folder['nfs-version'] if folder['nfs-version']
          options[:nfs_udp] = folder['nfs-udp'] if folder.key?('nfs-udp')
          options[:linux__nfs_options] = folder['linux-nfs-options'] if folder['linux-nfs-options']
          options[:bsd__nfs_options] = folder['bsd-nfs-options'] if folder['bsd-nfs-options']
        end

        def build_rsync_options(options, folder)
          options[:type] = 'rsync'
          options[:rsync__exclude] = folder['rsync-exclude'] if folder['rsync-exclude']
          options[:rsync__args] = folder['rsync-args'] if folder['rsync-args']
          options[:rsync__auto] = folder['rsync-auto'] if folder.key?('rsync-auto')
        end

        def build_smb_options(options, folder)
          options[:type] = 'smb'
          options[:smb_host] = folder['smb-host'] if folder['smb-host']
          options[:smb_username] = folder['smb-username'] if folder['smb-username']
          options[:smb_password] = folder['smb-password'] if folder['smb-password']
        end
      end
    end
  end
end
