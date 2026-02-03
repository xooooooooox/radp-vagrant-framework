# Plugins

Configure Vagrant plugins with YAML configuration.

## Basic Syntax

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      enabled: true
```

## Supported Plugins

- `vagrant-hostmanager` - Host file management
- `vagrant-vbguest` - VirtualBox Guest Additions
- `vagrant-proxyconf` - Proxy configuration
- `vagrant-bindfs` - Bind mounts
- `vagrant-disksize` - Disk resizing

## vagrant-hostmanager

Manages `/etc/hosts` on host and guest machines.

### YAML Configuration

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      enabled: true
      manage_host: true
      manage_guest: true
      include_offline: false
```

### Equivalent Vagrantfile

```ruby
config.hostmanager.enabled = true
config.hostmanager.manage_host = true
config.hostmanager.manage_guest = true
config.hostmanager.include_offline = false
```

### Provisioner Mode

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      manage_host: true
```

> Note: `provisioner` and `enabled` are mutually exclusive.

### Custom IP Resolver

**YAML:**

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      ip_resolver:
        enabled: true
        execute: "hostname -I"
        regex: "^(\\S+)"
```

### Per-Guest Settings

```yaml
guests:
  - id: node-1
    hostmanager:
      aliases:
        - myhost.local
        - myhost
      ip-resolver:
        enabled: true
        execute: "hostname -I | cut -d ' ' -f 2"
```

## vagrant-vbguest

Automatically installs VirtualBox Guest Additions.

### YAML Configuration

```yaml
plugins:
  - name: vagrant-vbguest
    required: true
    options:
      auto_update: true
      auto_reboot: true
```

### Equivalent Vagrantfile

```ruby
config.vbguest.auto_update = true
config.vbguest.auto_reboot = true
```

### All Options

| Option            | Type    | Default | Description               |
|-------------------|---------|---------|---------------------------|
| `auto_update`     | boolean | `true`  | Check/update on VM start  |
| `no_remote`       | boolean | `false` | Prevent downloading ISO   |
| `no_install`      | boolean | `false` | Only check version        |
| `auto_reboot`     | boolean | `true`  | Reboot after installation |
| `allow_downgrade` | boolean | `true`  | Allow older versions      |
| `iso_path`        | string  | -       | Custom ISO path           |
| `installer`       | string  | auto    | Installer type            |

## vagrant-bindfs

Fixes NFS permission issues by remapping ownership.

### YAML Configuration

```yaml
synced-folders:
  nfs:
    - host: ./data
      guest: /data
      bindfs:
        enabled: true
        force_user: vagrant
        force_group: vagrant
```

### Equivalent Vagrantfile

```ruby
config.vm.synced_folder "./data", "/data-nfs", type: "nfs"
config.bindfs.bind_folder "/data-nfs", "/data",
                          force_user: "vagrant",
                          force_group: "vagrant"
```

### With Permission Mapping

```yaml
synced-folders:
  nfs:
    - host: ./app
      guest: /var/www/app
      bindfs:
        enabled: true
        force_user: www-data
        force_group: www-data
        perms: "u=rwX:g=rX:o=rX"
```

### Global Options

```yaml
plugins:
  - name: vagrant-bindfs
    options:
      debug: false
      force_empty_mountpoints: true
      default_options:
        force_user: vagrant
        force_group: vagrant
```

## vagrant-disksize

Resizes the primary disk of VirtualBox VMs.

### Plugin Configuration

```yaml
plugins:
  - name: vagrant-disksize
    required: true
```

### Per-Guest Disk Size

```yaml
guests:
  - id: k8s-master
    disk_size: 50GB
    box:
      name: ubuntu/jammy64
```

### Size Formats

| Format  | Example | Description      |
|---------|---------|------------------|
| With GB | `50GB`  | 50 gigabytes     |
| Number  | `50`    | Defaults to 50GB |
| With TB | `1TB`   | 1 terabyte       |

> Note: Only works with VirtualBox provider.

## Plugin Merge Behavior

Plugins with the same name in base and env files have their options deep merged:

**Base config (vagrant.yaml):**

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      manage_host: true
```

**Env config (vagrant-dev.yaml):**

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      ip_resolver:
        enabled: true
```

**Result:**

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true            # inherited from base
    options:
      manage_host: true       # inherited from base
      provisioner: enabled    # added from env
      ip_resolver: { ... }    # added from env
```

## See Also

- [Configuration Reference](../configuration.md) - Full configuration options
- [Synced Folders](../configuration.md#synced-folders) - Folder synchronization
