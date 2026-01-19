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
- **Configuration Inheritance**: Global → Cluster → Guest with automatic merging
- **Array Concatenation**: Provisions, triggers, and synced-folders accumulate across inheritance levels
- **Extensible Design**: Plugin and provider registries for easy extension
- **Multi-Cluster Support**: Organize VMs into logical clusters

## Quick Start

```bash
cd src/main/ruby

# Validate configuration
vagrant validate

# Show VM status
vagrant status

# Start all VMs
vagrant up

# Start specific VM
vagrant up dev-node-1
```

## Directory Structure

```
src/main/ruby/
├── Vagrantfile                 # Entry point
├── config/
│   ├── vagrant-dev.yaml        # dev configuration
│   ├── vagrant-test.yaml       # test configuration
│   └── vagrant.yaml            # User configuration
└── lib/
    ├── radp_vagrant.rb         # Main coordinator
    └── radp_vagrant/
        ├── config_loader.rb    # YAML loading & validation
        ├── config_merger.rb    # Deep merge with array concatenation
        └── configurators/
            ├── box.rb          # Box configuration
            ├── provider.rb     # Provider (VirtualBox, etc.)
            ├── network.rb      # Network settings
            ├── synced_folder.rb # Synced folders
            ├── provision.rb    # Provisioners
            ├── trigger.rb      # Triggers
            └── plugin.rb       # Plugin management
```

## Configuration Structure

```yaml
radp:
  env: default
  extend:
    vagrant:
      # Plugin Management
      plugins:
        - name: vagrant-hostmanager
          enabled: true
          options:
            enabled: true
            manage-host: true

      config:
        # Global common (inherited by all guests)
        common:
          synced-folders:
            basic:
              - enabled: true
                host: ./shared
                guest: /vagrant/shared
          provisions:
            - name: global-init
              enabled: true
              type: shell
              run: once
              inline: echo "Hello"
          triggers:
            - name: startup
              enabled: true
              on: before
              type: action
              action:
                - up
              run:
                inline: echo "Starting..."

        # Cluster definitions
        clusters:
          - name: my-cluster
            common:
              box:
                name: generic/centos9s
                version: 4.3.12
              provider:
                type: virtualbox
                mem: 2048
                cpus: 2

            guests:
              - id: node-1
                provider:
                  name: node-1
                  mem: 4096
                network:
                  hostname: node-1.local
                  private-network:
                    enabled: true
                    type: dhcp
```

## Configuration Reference

### Plugins

```yaml
plugins:
  - name: vagrant-hostmanager    # Plugin name
    enabled: true                # Enable/disable
    options:                     # Plugin-specific options
      enabled: true
      manage-host: true
      manage-guest: true
```

### Box

```yaml
box:
  name: generic/centos9s         # Box name
  version: 4.3.12                # Box version
  check-update: false            # Disable update check
```

### Provider

```yaml
provider:
  type: virtualbox               # Provider type
  name: my-vm                    # VM name in provider
  group-id: my-group             # VirtualBox group
  mem: 2048                      # Memory in MB
  cpus: 2                        # CPU count
  gui: false                     # Show GUI
```

### Network

```yaml
network:
  hostname: node.local           # VM hostname
  private-network:
    enabled: true
    type: dhcp                   # dhcp or static
    ip: 192.168.56.10            # For static type
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
  hostmanager:
    enabled: true
    aliases:
      - myhost.local
```

### Synced Folders

```yaml
synced-folders:
  basic:
    - enabled: true
      host: ./data               # Host path
      guest: /data               # Guest mount path
      create: true               # Create if not exists
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
  - name: setup                  # Provision name
    desc: 'Setup script'         # Description
    enabled: true
    type: shell                  # shell or file
    privileged: false            # Run as root
    run: once                    # once, always, never
    inline: |                    # Inline script
      echo "Hello"
    # Or use path:
    # path: ./scripts/setup.sh
    # args: arg1 arg2
    before: other-provision      # Run before
    after: other-provision       # Run after
```

### Triggers

```yaml
triggers:
  - name: before-up              # Trigger name
    desc: 'Pre-start trigger'    # Description
    enabled: true
    on: before                   # before or after
    type: action                 # action, command, hook
    action:                      # Actions to trigger on
      - up
      - reload
    only-on:                     # Filter guests (supports regex)
      - '/node-.*/'
    run:
      inline: |                  # Local script
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
  - provisions: [A, B, C]        # All accumulated
  - synced-folders: [X, Y]       # All accumulated
```

## Generate Vagrantfile for Inspection

Generate a standalone Vagrantfile to inspect the resolved configuration:

```bash
cd src/main/ruby
ruby lib/radp_vagrant/generator.rb > Vagrantfile.generated

# Or with custom config path
ruby lib/radp_vagrant/generator.rb config/vagrant.yaml > Vagrantfile.generated
```

## Environment Variables

- `RADP_VAGRANT_CONFIG` - Override configuration file path

## Extending

### Add Provider

```ruby
# In provider.rb
RadpVagrant::Configurators::Provider::CONFIGURATORS['vmware_desktop'] = lambda { |provider, opts|
  provider.vmx['memsize'] = opts['mem']
  provider.vmx['numvcpus'] = opts['cpus']
}
```

### Add Plugin

```ruby
# In plugin.rb
RadpVagrant::Configurators::Plugin::CONFIGURATORS['my-plugin'] = lambda { |config, opts|
  config.my_plugin.option = opts['value']
}
```

## License

MIT
