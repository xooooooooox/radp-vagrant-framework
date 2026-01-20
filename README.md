# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

A YAML-driven framework for managing multi-machine Vagrant environments with declarative configuration.

## Features

- **Declarative YAML Configuration**: Define VMs, networks, provisions, and triggers in YAML
- **Multi-File Configuration**: Base config + environment-specific overrides (`vagrant.yaml` + `vagrant-{env}.yaml`)
- **Configuration Inheritance**: Global → Cluster → Guest with automatic merging
- **Array Concatenation**: Provisions, triggers, and synced-folders accumulate across inheritance levels
- **Modular Plugin System**: Each plugin configurator in its own file for easy maintenance
- **Convention-Based Defaults**: Automatic hostname, provider name, and group-id generation
- **Dry-Run Preview**: Generate standalone Vagrantfile to inspect final configuration
- **Configuration Validation**: Detect duplicate cluster names and guest IDs
- **Debug Support**: Dump final merged configuration for inspection (JSON/YAML)

## Quick Start

```bash
cd src/main/ruby

# Validate configuration
vagrant validate

# Show VM status
vagrant status

# Start all VMs
vagrant up

# Start specific VM (use machine_name: <env>-<cluster>-<guest-id>)
vagrant up dev-my-cluster-node-1

# Debug: dump merged configuration (JSON)
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"

# Filter by guest_id or machine_name
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', 'node-1')"
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', 'dev-my-cluster-node-1')"

# Output as YAML
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', nil, format: :yaml)"

# Generate standalone Vagrantfile (dry-run preview)
ruby -r ./lib/radp_vagrant -e "puts RadpVagrant.generate_vagrantfile('config')"

# Save generated Vagrantfile
ruby -r ./lib/radp_vagrant -e "RadpVagrant.generate_vagrantfile('config', 'Vagrantfile.generated')"
```

## Directory Structure

```
src/main/ruby/
├── Vagrantfile                     # Entry point
├── config/
│   ├── vagrant.yaml                # Base configuration (sets env)
│   ├── vagrant-dev.yaml            # Dev environment clusters
│   └── vagrant-local.yaml          # Local environment clusters
└── lib/
    ├── radp_vagrant.rb             # Main coordinator
    └── radp_vagrant/
        ├── config_loader.rb        # Multi-file YAML loading
        ├── config_merger.rb        # Deep merge with array concatenation
        ├── generator.rb            # Vagrantfile generator (dry-run)
        └── configurators/
            ├── box.rb              # Box configuration
            ├── provider.rb         # Provider (VirtualBox, etc.)
            ├── network.rb          # Network & hostname
            ├── hostmanager.rb      # Per-guest hostmanager
            ├── synced_folder.rb    # Synced folders
            ├── provision.rb        # Provisioners
            ├── trigger.rb          # Triggers
            ├── plugin.rb           # Plugin orchestrator
            └── plugins/            # Modular plugin configurators
                ├── base.rb         # Base class
                ├── registry.rb     # Plugin registry
                ├── hostmanager.rb  # vagrant-hostmanager
                ├── vbguest.rb      # vagrant-vbguest
                ├── proxyconf.rb    # vagrant-proxyconf
                └── bindfs.rb       # vagrant-bindfs
```

## Configuration Structure

### Multi-File Loading

Configuration is loaded in order with deep merging:
1. `vagrant.yaml` - Base configuration (must contain `radp.env`)
2. `vagrant-{env}.yaml` - Environment-specific clusters

```yaml
# vagrant.yaml - Base configuration
radp:
  env: dev  # Determines which env file to load
  extend:
    vagrant:
      plugins:
        - name: vagrant-hostmanager
          required: true
          options:
            enabled: true
            manage_host: true
      config:
        common:
          # Global settings inherited by all guests
          provisions:
            - name: global-init
              enabled: true
              type: shell
              run: once
              inline: echo "Hello"

# vagrant-dev.yaml - Dev environment
radp:
  extend:
    vagrant:
      config:
        clusters:
          - name: my-cluster
            guests:
              - id: node-1
                box:
                  name: generic/centos9s
```

## Configuration Reference

### Plugins

```yaml
plugins:
  - name: vagrant-hostmanager     # Plugin name
    required: true                # Auto-install if missing
    options:                      # Plugin-specific options (use underscores)
      enabled: true
      manage_host: true
      manage_guest: true
      include_offline: true
```

Supported plugins:
- `vagrant-hostmanager` - Host file management
- `vagrant-vbguest` - VirtualBox Guest Additions
- `vagrant-proxyconf` - Proxy configuration
- `vagrant-bindfs` - Bind mounts (per synced-folder)

### Box

```yaml
box:
  name: generic/centos9s          # Box name
  version: 4.3.12                 # Box version
  check-update: false             # Disable update check
```

### Provider

```yaml
provider:
  type: virtualbox                # Provider type
  name: my-vm                     # VM name (default: {env}-{cluster}-{guest-id})
  group-id: my-group              # VirtualBox group (default: {env}/{cluster})
  mem: 2048                       # Memory in MB
  cpus: 2                         # CPU count
  gui: false                      # Show GUI
```

### Network

```yaml
# Hostname at guest level (default: {guest-id}.{cluster}.{env})
hostname: node.local

network:
  private-network:
    enabled: true
    type: dhcp                    # dhcp or static
    ip: 192.168.56.10             # For static type
    netmask: 255.255.255.0
  public-network:
    enabled: true
    type: static
    ip: 192.168.1.100
    bridge:
      - "en0: Wi-Fi"
  forwarded-ports:
    - enabled: true
      guest: 80
      host: 8080
      protocol: tcp
```

### Hostmanager (Per-Guest)

```yaml
hostmanager:
  aliases:
    - myhost.local
    - myhost
  ip-resolver:
    enabled: true
    execute: "hostname -I | cut -d ' ' -f 2"
    regex: "^(\\S+)"
```

### Synced Folders

```yaml
synced-folders:
  basic:
    - enabled: true
      host: ./data                # Host path
      guest: /data                # Guest mount path
      create: true                # Create if not exists
      owner: vagrant
      group: vagrant
  nfs:
    - enabled: true
      host: ./nfs-data
      guest: /nfs-data
      nfs-version: 4
  smb:
    - enabled: true
      host: ./smb-data
      guest: /smb-data
      smb-host: 192.168.1.1
      smb-username: user
      smb-password: pass
```

### Provisions

```yaml
provisions:
  - name: setup                   # Provision name
    desc: 'Setup script'          # Description
    enabled: true
    type: shell                   # shell or file
    privileged: false             # Run as root
    run: once                     # once, always, never
    inline: |                     # Inline script
      echo "Hello"
    # Or use path:
    # path: ./scripts/setup.sh
    # args: arg1 arg2
    # before: other-provision     # Run before (provision must exist)
    # after: other-provision      # Run after
```

### Triggers

Note: The `on` key must be quoted in YAML to prevent parsing as boolean.

```yaml
triggers:
  - name: before-up               # Trigger name
    desc: 'Pre-start trigger'     # Description
    enabled: true
    "on": before                  # before or after (must be quoted!)
    type: action                  # action, command, hook
    action:                       # Actions to trigger on
      - up
      - reload
    only-on:                      # Filter guests (supports regex)
      - '/node-.*/'
    run:
      inline: |                   # Local script
        echo "Starting..."
    # Or run-remote for guest execution
```

## Configuration Inheritance

Configuration flows from global → cluster → guest. Arrays (provisions, triggers, synced-folders) are **concatenated**, not replaced:

```
Global common:
  - provisions: [A]
  - synced-folders: [X]

Cluster common:
  - provisions: [B]
  - synced-folders: [Y]

Guest:
  - provisions: [C]

Result for guest:
  - provisions: [A, B, C]         # All accumulated
  - synced-folders: [X, Y]        # All accumulated
```

## Convention-Based Defaults

The framework applies sensible defaults based on context:

| Field | Default Value | Example |
|-------|--------------|---------|
| `hostname` | `{guest-id}.{cluster}.{env}` | `node-1.my-cluster.dev` |
| `provider.name` | `{env}-{cluster}-{guest-id}` | `dev-my-cluster-node-1` |
| `provider.group-id` | `{env}/{cluster}` | `dev/my-cluster` |

## Validation Rules

The framework validates configurations and will raise errors for:

- **Duplicate cluster names**: No two clusters in the same environment file can have the same name
- **Duplicate guest IDs**: No two guests within the same cluster can have the same ID
- **Clusters in base config**: Clusters must be defined in `vagrant-{env}.yaml`, not in base `vagrant.yaml`

## Machine Naming

Vagrant machine names use `provider.name` (default: `{env}-{cluster}-{guest-id}`) to ensure uniqueness in `$VAGRANT_DOTFILE_PATH/machines/<name>`. This prevents conflicts when multiple clusters have guests with the same ID.

## Environment Variables

- `RADP_VAGRANT_CONFIG_DIR` - Override configuration directory path

## Extending

### Add New Plugin Configurator

1. Create file `lib/radp_vagrant/configurators/plugins/my_plugin.rb`:

```ruby
# frozen_string_literal: true

require_relative 'base'

module RadpVagrant
  module Configurators
    module Plugins
      class MyPlugin < Base
        class << self
          def plugin_name
            'vagrant-my-plugin'
          end

          def configure(vagrant_config, options)
            return unless options

            config = vagrant_config.my_plugin
            set_if_present(config, :option1, options, 'option1')
            set_if_present(config, :option2, options, 'option2')
          end
        end
      end
    end
  end
end
```

2. Add to `plugins/registry.rb`:

```ruby
require_relative 'my_plugin'

def plugin_classes
  [
    Hostmanager,
    Vbguest,
    Proxyconf,
    Bindfs,
    MyPlugin  # Add here
  ]
end
```

### Add Provider

```ruby
# In provider.rb
RadpVagrant::Configurators::Provider::CONFIGURATORS['vmware_desktop'] = lambda { |provider, opts|
  provider.vmx['memsize'] = opts['mem']
  provider.vmx['numvcpus'] = opts['cpus']
}
```

## License

MIT
