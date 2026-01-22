# frozen_string_literal: true

module RadpVagrant
  module Configurators
    # Configures VM synced folders (basic, nfs, rsync, smb)
    # Reference: https://developer.hashicorp.com/vagrant/docs/synced-folders/basic_usage
    module SyncedFolder
      # Prefix for temporary NFS mount paths when using bindfs
      BINDFS_MOUNT_PREFIX = '/mnt-bindfs'

      class << self
        def configure(vm_config, guest)
          folders = guest['synced-folders']
          return unless folders

          folders.each do |folder|
            # Skip if explicitly disabled via 'enabled: false'
            next if folder['enabled'] == false

            configure_folder(vm_config, folder)
          end
        end

        private

        def configure_folder(vm_config, folder)
          host_path = folder['host']
          guest_path = folder['guest']
          folder_type = folder['type'] || 'basic'

          return unless host_path && guest_path

          # Check if bindfs is enabled for NFS folders
          bindfs_config = folder['bindfs']
          use_bindfs = bindfs_config && bindfs_config['enabled'] && folder_type == 'nfs'

          if use_bindfs
            configure_nfs_with_bindfs(vm_config, folder, host_path, guest_path, bindfs_config)
          else
            options = build_options(folder, folder_type)
            vm_config.vm.synced_folder host_path, guest_path, **options
          end
        end

        def configure_nfs_with_bindfs(vm_config, folder, host_path, guest_path, bindfs_config)
          # Mount NFS to a temporary path
          temp_path = "#{BINDFS_MOUNT_PREFIX}#{guest_path}"

          # Build NFS options and mount to temp path
          nfs_options = build_options(folder, 'nfs')
          vm_config.vm.synced_folder host_path, temp_path, **nfs_options

          # Build bindfs options
          bindfs_options = build_bindfs_options(bindfs_config)

          # Configure bindfs to remount with correct permissions
          vm_config.bindfs.bind_folder temp_path, guest_path, bindfs_options
        end

        def build_bindfs_options(config)
          options = {}

          # Ownership options
          options[:force_user] = config['force_user'] if config['force_user']
          options[:force_group] = config['force_group'] if config['force_group']

          # Permission options
          options[:perms] = config['perms'] if config['perms']
          options[:create_with_perms] = config['create_with_perms'] if config['create_with_perms']

          # Behavior options
          options[:create_as_user] = config['create_as_user'] if config.key?('create_as_user')
          options[:chown_ignore] = config['chown_ignore'] if config.key?('chown_ignore')
          options[:chgrp_ignore] = config['chgrp_ignore'] if config.key?('chgrp_ignore')

          # Mount options
          options[:o] = config['o'] if config['o']
          options[:after] = config['after'].to_sym if config['after']

          options
        end

        def build_options(folder, folder_type)
          options = {}

          # Common options for all types
          options[:create] = folder['create'] if folder.key?('create')
          options[:disabled] = folder['disabled'] if folder.key?('disabled')
          options[:id] = folder['id'] if folder['id']

          # Type-specific options
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
