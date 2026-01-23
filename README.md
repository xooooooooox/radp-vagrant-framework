# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

[![CI](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/ci.yml?label=CI)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/ci.yml)
[![CI: Homebrew](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/update-homebrew-tap.yml?label=Homebrew%20tap)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/update-homebrew-tap.yml)

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

## QuickStart

### Installation

Prerequisites:

- Ruby 2.7+. (You can install Ruby here: <https://www.ruby-lang.org/en/documentation/installation/>)
- Vagrant 2.0+. (You can install Vagrant here: <https://developer.hashicorp.com/vagrant/install>)
- VirtualBox (or other supported provider)

#### Script (curl / wget / fetch)

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/tools/install.sh
| bash
```

Or:

```shell
wget -qO- https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/tools/install.sh
| bash
```

Optional variables:

```shell
RADP_VF_VERSION=vX.Y.Z \
  RADP_VF_REF=main \
  RADP_VF_INSTALL_DIR="$HOME/.local/lib/radp-vagrant-framework" \
  RADP_VF_BIN_DIR="$HOME/.local/bin" \
  RADP_VF_ALLOW_ANY_DIR=1 \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/tools/install.sh)"
```

`RADP_VF_REF` can be a branch, tag, or commit and takes precedence over `RADP_VF_VERSION`.
If you set a custom install dir that does not end with `radp-vagrant-framework`, also set `RADP_VF_ALLOW_ANY_DIR=1`.
Defaults: `~/.local/lib/radp-vagrant-framework` and `~/.local/bin`.

Re-run the script to upgrade.

#### Homebrew (macOS/Linux)

Click [here](https://github.com/xooooooooox/homebrew-radp/blob/main/Formula/radp-vagrant-framework.rb) see details.

```shell
brew tap xooooooooox/radp
brew install radp-vagrant-framework
```

#### Manual (Git clone / Release assets)

Prebuilt release archives are attached to each
release: <https://github.com/xooooooooox/radp-vagrant-framework/releases/latest>

Or clone the repository:

```shell
git clone https://github.com/xooooooooox/radp-vagrant-framework.git
cd radp-vagrant-framework/src/main/ruby
```

### Upgrade

#### Script

Re-run the installation script to upgrade to the latest version.

#### Homebrew

```shell
brew upgrade radp-vagrant-framework
```

#### Manual

Download the new release archive from the latest release and extract it, or `git pull` if using a cloned repository.

## How to Use

### Initialize a New Project

After installation, create a new project with sample configuration:

```shell
radp-vf init myproject
```

This creates the following structure:

```
myproject/
└── config/
    ├── vagrant.yaml          # Base configuration (sets env)
    ├── vagrant-sample.yaml   # Environment-specific clusters
    └── provisions/           # User-defined provisions
        ├── definitions/
        │   └── example.yaml  # Example provision definition
        └── scripts/
            └── example.sh    # Example provision script
```

The framework's Vagrantfile is used automatically via `radp-vf vg` - no Vagrantfile is created in your project
directory.

### Configuration Files

The framework uses a two-file configuration approach:

1. **`config/vagrant.yaml`** - Base configuration (required)
    - Must contain `radp.env` to specify the environment
    - Defines global settings, plugins, and common configurations

2. **`config/vagrant-{env}.yaml`** - Environment-specific clusters
    - `{env}` matches the value of `radp.env` in the base config
    - Defines clusters and guests for this environment

Example minimal configuration:

```yaml
# config/vagrant.yaml
radp:
  env: dev    # Will load config/vagrant-dev.yaml
  extend:
    vagrant:
      config:
        common:
          box:
            name: generic/ubuntu2204
```

```yaml
# config/vagrant-dev.yaml
radp:
  extend:
    vagrant:
      config:
        clusters:
          - name: my-cluster
            guests:
              - id: node-1
                provider:
                  mem: 2048
                  cpus: 2
```

### Environment Variables

| Variable                  | Description                                      | Default                            |
|---------------------------|--------------------------------------------------|------------------------------------|
| `RADP_VF_HOME`            | Framework installation directory                 | Auto-detected from script location |
| `RADP_VAGRANT_CONFIG_DIR` | Configuration directory path (required for `vg`) | `./config` if exists               |
| `RADP_VAGRANT_ENV`        | Override environment name                        | `radp.env` in vagrant.yaml         |

**RADP_VF_HOME defaults:**

- Script/Homebrew install: `~/.local/lib/radp-vagrant-framework` or
  `/opt/homebrew/Cellar/radp-vagrant-framework/<version>/libexec`
- Git clone: `<repo>/src/main/ruby` (auto-detected)

**Environment priority (highest to lowest):**

```
-e flag > RADP_VAGRANT_ENV > radp.env in vagrant.yaml
```

### Running Vagrant Commands

Use `radp-vf vg` to run vagrant commands. This works from the project directory or anywhere if `RADP_VAGRANT_CONFIG_DIR`
is set:

```shell
# From project directory (contains config/vagrant.yaml)
cd myproject
radp-vf vg status
radp-vf vg up
radp-vf vg ssh sample-example-node-1
radp-vf vg halt
radp-vf vg destroy

# Or from any directory with RADP_VAGRANT_CONFIG_DIR set
export RADP_VAGRANT_CONFIG_DIR="$HOME/myproject/config"
radp-vf vg status
radp-vf vg up

# Override environment with -e flag
radp-vf -e dev vg status # Uses vagrant-dev.yaml
radp-vf -e prod vg up # Uses vagrant-prod.yaml
```

**Note:** Native `vagrant` commands are isolated from `radp-vf vg`. Running `vagrant up` in a directory with its own
Vagrantfile works normally and is not affected by RADP Vagrant Framework.

**Recommended: Set `VAGRANT_DOTFILE_PATH` for remote config directories**

When using `RADP_VAGRANT_CONFIG_DIR` to run commands from any directory, Vagrant stores machine state (`.vagrant`
directory) in the current working directory by default. This can cause issues:

- Machine state scattered across different directories
- "This machine used to live in..." warnings when running from different paths

To avoid these issues, set `VAGRANT_DOTFILE_PATH` to a fixed location:

```shell
# Add to ~/.bashrc or ~/.zshrc
export RADP_VAGRANT_CONFIG_DIR="$HOME/.config/radp-vagrant"
export VAGRANT_DOTFILE_PATH="$HOME/.config/radp-vagrant/.vagrant"
```

This ensures Vagrant always uses the same `.vagrant` directory regardless of where you run commands.

### Debug Commands

```shell
# Show environment info
radp-vf info

# Dump merged configuration (JSON)
radp-vf dump-config

# Filter by guest ID or machine name
radp-vf dump-config node-1

# Generate standalone Vagrantfile (dry-run preview)
radp-vf generate

# Save generated Vagrantfile
radp-vf generate Vagrantfile.preview
```

### Use from Git Clone (Development)

For framework development or direct use from source:

```bash
cd radp-vagrant-framework/src/main/ruby

# Validate configuration
vagrant validate

# Show VM status
vagrant status

# Debug: dump merged configuration
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"

# Output as YAML
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', nil, format: :yaml)"

# Generate standalone Vagrantfile
ruby -r ./lib/radp_vagrant -e "puts RadpVagrant.generate_vagrantfile('config')"
```

## Directory Structure

```
src/main/ruby/
├── Vagrantfile                     # Entry point
├── config/
│   ├── vagrant.yaml                # Base configuration (sets env)
│   ├── vagrant-sample.yaml         # Sample environment clusters
│   └── vagrant-local.yaml          # Local environment clusters
└── lib/
    ├── radp_vagrant.rb             # Main coordinator
    └── radp_vagrant/
        ├── config_loader.rb        # Multi-file YAML loading
        ├── config_merger.rb        # Deep merge with array concatenation
        ├── generator.rb            # Vagrantfile generator (dry-run)
        ├── path_resolver.rb        # Unified two-level path resolution
        ├── configurators/
        │   ├── box.rb              # Box configuration
        │   ├── provider.rb         # Provider (VirtualBox, etc.)
        │   ├── network.rb          # Network & hostname
        │   ├── hostmanager.rb      # Per-guest hostmanager
        │   ├── synced_folder.rb    # Synced folders
        │   ├── provision.rb        # Provisioners
        │   ├── trigger.rb          # Triggers
        │   ├── plugin.rb           # Plugin orchestrator
        │   └── plugins/            # Modular plugin configurators
        │       ├── base.rb         # Base class
        │       ├── registry.rb     # Plugin registry
        │       ├── hostmanager.rb  # vagrant-hostmanager
        │       ├── vbguest.rb      # vagrant-vbguest
        │       ├── proxyconf.rb    # vagrant-proxyconf
        │       └── bindfs.rb       # vagrant-bindfs
        └── provisions/             # Builtin & user provisions
            ├── registry.rb         # Builtin provision registry (radp:)
            ├── user_registry.rb    # User provision registry (user:)
            ├── definitions/        # Provision definitions (YAML)
            │   └── nfs/
            │       └── external-nfs-mount.yaml
            └── scripts/            # Provision scripts
                └── nfs/
                    └── external-nfs-mount.sh
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

Plugins are configured in the `plugins` array. Each plugin can specify:

- `name`: Plugin name (required)
- `required`: Auto-install if missing (default: false)
- `options`: Plugin-specific configuration options

Supported plugins:

- `vagrant-hostmanager` - Host file management
- `vagrant-vbguest` - VirtualBox Guest Additions
- `vagrant-proxyconf` - Proxy configuration
- `vagrant-bindfs` - Bind mounts (per synced-folder)

#### vagrant-hostmanager

Manages `/etc/hosts` on host and guest machines for hostname resolution.

**Basic configuration (automatic mode):**

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      enabled: true               # Update hosts on vagrant up/destroy
      manage_host: true           # Update host machine's /etc/hosts
      manage_guest: true          # Update guest machines' /etc/hosts
      include_offline: false      # Include offline VMs in hosts file
```

**Provisioner mode:**

Use `provisioner: enabled` to run hostmanager as a provisioner instead of automatically. This gives you control over
when hosts file is updated:

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled        # Run as provisioner (mutually exclusive with enabled)
      manage_host: true
      manage_guest: true
```

> Note: `provisioner` and `enabled` are mutually exclusive. If both are set, the framework automatically disables
`enabled` and logs a warning.

**Custom IP resolver:**

By default, hostmanager uses `vm.ssh_info[:host]` which may return `127.0.0.1` for NAT networking. Use `ip_resolver` to
extract the correct IP from guest:

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      manage_host: true
      ip_resolver:
        enabled: true
        execute: "hostname -I"    # Command to run on guest
        regex: "^(\\S+)"          # Regex to extract IP (first capture group)
```

**Execution timing:**

When `provisioner: enabled`, hostmanager runs **after all other provisions**:

```
global-pre → cluster-pre → guest → cluster-post → global-post → hostmanager
```

**Triggering on running VMs:**

```bash
# Trigger only hostmanager (skip other provisions)
radp-vf vg provision --provision-with hostmanager

# Run all provisioners including hostmanager
radp-vf vg provision
```

#### vagrant-vbguest

Automatically installs and updates VirtualBox Guest Additions on guest machines.

##### Recommended configuration

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      auto_update: true           # Check/update on VM start (default: true)
      auto_reboot: true           # Reboot after installation if needed
```

##### Distribution-specific configurations

<details>
<summary><b>Ubuntu / Debian</b></summary>

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      installer: ubuntu           # or debian
      auto_update: true
      auto_reboot: true
```

</details>

<details>
<summary><b>CentOS / RHEL / Rocky Linux</b></summary>

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      installer: centos
      auto_update: true
      auto_reboot: true
      installer_options:
        allow_kernel_upgrade: true    # Allow kernel upgrade if needed
        reboot_timeout: 300           # Wait time after kernel upgrade (seconds)
```

> Note: CentOS may require kernel upgrade when Guest Additions version mismatches. Set `allow_kernel_upgrade: true` to
> allow this.

</details>

<details>
<summary><b>Fedora</b></summary>

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      installer: fedora
      auto_update: true
      auto_reboot: true
```

</details>

##### Common use cases

| Scenario               | Configuration                                  |
|------------------------|------------------------------------------------|
| Disable auto-update    | `auto_update: false`                           |
| Check only, no install | `no_install: true`                             |
| Offline environment    | `no_remote: true` + `iso_path: "/path/to/iso"` |
| Allow downgrade        | `allow_downgrade: true` (default)              |

**Offline / Air-gapped environment:**

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      no_remote: true
      iso_path: "/shared/VBoxGuestAdditions.iso"
      iso_upload_path: "/tmp"
      iso_mount_point: "/mnt"
```

**Disable completely (use box's built-in Guest Additions):**

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      auto_update: false
      no_install: true
```

<details>
<summary><b>All available options</b></summary>

| Option                | Type    | Default       | Description                                                           |
|-----------------------|---------|---------------|-----------------------------------------------------------------------|
| `auto_update`         | boolean | `true`        | Check/update Guest Additions on VM start                              |
| `no_remote`           | boolean | `false`       | Prevent downloading ISO from remote                                   |
| `no_install`          | boolean | `false`       | Only check version, don't install                                     |
| `auto_reboot`         | boolean | `true`        | Reboot after installation if needed                                   |
| `allow_downgrade`     | boolean | `true`        | Allow installing older versions                                       |
| `iso_path`            | string  | -             | Custom ISO path (local or URL with `%{version}`)                      |
| `iso_upload_path`     | string  | `/tmp`        | Guest directory for ISO upload                                        |
| `iso_mount_point`     | string  | `/mnt`        | Guest mount point for ISO                                             |
| `installer`           | string  | auto          | Installer type: `linux`, `ubuntu`, `debian`, `centos`, `fedora`, etc. |
| `installer_arguments` | array   | `["--nox11"]` | Arguments passed to installer                                         |
| `yes`                 | boolean | `true`        | Auto-respond yes to prompts                                           |
| `installer_options`   | hash    | -             | Distro-specific options                                               |
| `installer_hooks`     | hash    | -             | Hooks: `before_install`, `after_install`, etc.                        |

</details>

#### vagrant-bindfs

Fixes NFS permission issues by remapping user/group ownership via bindfs mounts.

##### Why use bindfs?

NFS shares inherit host numeric user/group IDs (e.g., macOS users appear as `501:20` inside guest). This causes
permission issues when guest user (typically `vagrant:vagrant`) cannot access the mounted files. vagrant-bindfs solves
this by remounting NFS shares with corrected ownership.

##### Recommended configuration

Configure bindfs per NFS folder in `synced-folders`:

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

This will:

1. Mount NFS to `/mnt-bindfs/data` (temp path)
2. Use bindfs to remount to `/data` with `vagrant:vagrant` ownership

##### With permission mapping

```yaml
synced-folders:
  nfs:
    - host: ./app
      guest: /var/www/app
      bindfs:
        enabled: true
        force_user: www-data
        force_group: www-data
        perms: "u=rwX:g=rX:o=rX"         # rwx for user, rx for group/other
        create_with_perms: "u=rwX:g=rX:o=rX"
```

##### Global plugin options

```yaml
plugins:
  - name: vagrant-bindfs
    options:
      debug: false                       # Enable debug output
      force_empty_mountpoints: true      # Clean mount point before mounting
      skip_validations: # Skip user/group existence checks
        - user
        - group
      default_options: # Default options for all bind_folder calls
        force_user: vagrant
        force_group: vagrant
```

<details>
<summary><b>All bindfs options (per folder)</b></summary>

| Option              | Type    | Description                                             |
|---------------------|---------|---------------------------------------------------------|
| `enabled`           | boolean | Enable bindfs for this folder                           |
| `force_user`        | string  | Force all files to be owned by this user                |
| `force_group`       | string  | Force all files to be owned by this group               |
| `perms`             | string  | Permission mapping (e.g., `u=rwX:g=rD:o=rD`)            |
| `create_with_perms` | string  | Permissions for newly created files                     |
| `create_as_user`    | boolean | Create files as the accessing user                      |
| `chown_ignore`      | boolean | Ignore chown operations                                 |
| `chgrp_ignore`      | boolean | Ignore chgrp operations                                 |
| `o`                 | string  | Additional mount options                                |
| `after`             | string  | When to bind: `synced_folders` (default) or `provision` |

</details>

<details>
<summary><b>All global plugin options</b></summary>

| Option                       | Type    | Default | Description                               |
|------------------------------|---------|---------|-------------------------------------------|
| `debug`                      | boolean | `false` | Enable verbose output                     |
| `force_empty_mountpoints`    | boolean | `false` | Clean mount destination before binding    |
| `skip_validations`           | array   | `[]`    | Skip validations: `user`, `group`         |
| `bindfs_version`             | string  | -       | Specific bindfs version to install        |
| `install_bindfs_from_source` | boolean | `false` | Build bindfs from source                  |
| `default_options`            | hash    | -       | Default options for all bind_folder calls |

</details>

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
  customize: # VirtualBox-specific customizations
    - [ 'modifyvm', ':id', '--nictype1', 'virtio' ]
```

<details>
<summary><b>All provider options (VirtualBox)</b></summary>

| Option      | Type    | Default                      | Description                                    |
|-------------|---------|------------------------------|------------------------------------------------|
| `type`      | string  | `virtualbox`                 | Provider type                                  |
| `name`      | string  | `{env}-{cluster}-{guest-id}` | VM name (used as Vagrant machine name)         |
| `group-id`  | string  | `{env}/{cluster}`            | VirtualBox group for organizing VMs            |
| `mem`       | number  | `2048`                       | Memory in MB                                   |
| `cpus`      | number  | `2`                          | Number of CPUs                                 |
| `gui`       | boolean | `false`                      | Show VirtualBox GUI                            |
| `customize` | array   | -                            | VirtualBox customize commands (modifyvm, etc.) |

</details>

### Network

```yaml
# Hostname at guest level (default: {guest-id}.{cluster}.{env})
hostname: node.local

network:
  private-network:
    enabled: true
    type: dhcp                    # dhcp or static
    ip: 192.168.56.10             # For static type (single IP)
    netmask: 255.255.255.0
  public-network:
    enabled: true
    type: static
    ip: # Multiple IPs supported (creates multiple interfaces)
      - 192.168.1.100
      - 192.168.1.101
    bridge:
      - "en0: Wi-Fi"
      - "en0: Ethernet"
  forwarded-ports:
    - enabled: true
      guest: 80
      host: 8080
      protocol: tcp
```

<details>
<summary><b>All network options</b></summary>

**Hostname:**

| Option     | Type   | Default                      | Description                  |
|------------|--------|------------------------------|------------------------------|
| `hostname` | string | `{guest-id}.{cluster}.{env}` | VM hostname (at guest level) |

**Private Network:**

| Option        | Type         | Default  | Description                                        |
|---------------|--------------|----------|----------------------------------------------------|
| `enabled`     | boolean      | -        | Enable private network                             |
| `type`        | string       | `static` | Network type: `dhcp` or `static`                   |
| `ip`          | string/array | -        | Static IP address(es); multiple creates interfaces |
| `netmask`     | string       | -        | Subnet mask (e.g., `255.255.255.0`)                |
| `auto-config` | boolean      | `true`   | Auto-configure network interface                   |

**Public Network:**

| Option                            | Type         | Default  | Description                                        |
|-----------------------------------|--------------|----------|----------------------------------------------------|
| `enabled`                         | boolean      | -        | Enable public network                              |
| `type`                            | string       | `static` | Network type: `dhcp` or `static`                   |
| `ip`                              | string/array | -        | Static IP address(es); multiple creates interfaces |
| `netmask`                         | string       | -        | Subnet mask                                        |
| `bridge`                          | string/array | -        | Bridge interface(s) on host                        |
| `auto-config`                     | boolean      | `true`   | Auto-configure network interface                   |
| `use-dhcp-assigned-default-route` | boolean      | `false`  | Use DHCP-assigned default route                    |

**Forwarded Ports:**

| Option         | Type    | Default | Description                                |
|----------------|---------|---------|--------------------------------------------|
| `enabled`      | boolean | -       | Enable this port forwarding                |
| `guest`        | number  | -       | Guest port (required)                      |
| `host`         | number  | -       | Host port (required)                       |
| `protocol`     | string  | `tcp`   | Protocol: `tcp` or `udp`                   |
| `id`           | string  | -       | Unique identifier for this port forward    |
| `auto-correct` | boolean | `false` | Auto-correct host port if collision occurs |

</details>

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
    privileged: true              # Run as root (default: false)
    run: once                     # once, always, never
    phase: pre                    # pre (default) or post - for common provisions only
    inline: |                     # Inline script
      echo "Hello $MY_VAR"
    env: # Environment variables
      MY_VAR: "world"
    # Or use path:
    # path: ./scripts/setup.sh
    # args: arg1 arg2
    # before: other-provision     # Run before (provision must exist)
    # after: other-provision      # Run after
```

**With external script and environment variables:**

```yaml
provisions:
  - name: mount-nfs
    enabled: true
    type: shell
    privileged: true
    run: always
    path: scripts/mount-nfs.sh
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume2/nfs"
```

**Script path resolution:**

The `path` option supports both absolute and relative paths. Relative paths are resolved using smart detection:

1. First, check if the path exists **relative to config directory**
2. If not found, check if the path exists **relative to project root** (config directory's parent)
3. If neither exists, use config-relative path (Vagrant will report the error)

This supports both standard project structures and custom `RADP_VAGRANT_CONFIG_DIR` setups.

| Path Type | Example                 | Resolution Order                                                           |
|-----------|-------------------------|----------------------------------------------------------------------------|
| Absolute  | `/opt/scripts/setup.sh` | Used as-is                                                                 |
| Relative  | `scripts/setup.sh`      | 1. `{config_dir}/scripts/setup.sh`<br>2. `{project_root}/scripts/setup.sh` |

**Supported directory structures:**

```
# Structure A: Standard project (radp-vf init)
myproject/                          # project root
├── config/                         # RADP_VAGRANT_CONFIG_DIR
│   ├── vagrant.yaml
│   └── vagrant-{env}.yaml
└── scripts/                        # path: scripts/setup.sh ✓
    └── setup.sh

# Structure B: Custom config directory
~/.config/radp-vagrant/             # RADP_VAGRANT_CONFIG_DIR
├── vagrant.yaml
├── vagrant-{env}.yaml
└── scripts/                        # path: scripts/setup.sh ✓
    └── setup.sh
```

Both structures work with `path: scripts/setup.sh`.

**Phase field (common provisions only):**

The `phase` field controls when common provisions run relative to guest provisions:

- `pre` (default): Runs before guest provisions
- `post`: Runs after guest provisions

```yaml
# vagrant.yaml - global common
common:
  provisions:
    - name: global-init
      phase: pre                  # Runs first (default)
      inline: echo "1. Global init"
    - name: global-cleanup
      phase: post                 # Runs last
      inline: echo "5. Global cleanup"

# vagrant-dev.yaml - cluster common
clusters:
  - name: my-cluster
    common:
      provisions:
        - name: cluster-init
          phase: pre
          inline: echo "2. Cluster init"
        - name: cluster-cleanup
          phase: post
          inline: echo "4. Cluster cleanup"
    guests:
      - id: node-1
        provisions:
          - name: guest-setup     # Guest provisions run in middle
            inline: echo "3. Guest setup"
```

Execution order: `global-pre → cluster-pre → guest → cluster-post → global-post`

#### Builtin Provisions

The framework provides builtin provisions for common tasks. Builtin provisions are identified by the `radp:` prefix and come with sensible defaults.

**Available builtin provisions:**

| Name                          | Description                                                | Defaults                        |
|-------------------------------|------------------------------------------------------------|---------------------------------|
| `radp:nfs/external-nfs-mount` | Mount external NFS shares with auto-directory and verification | `privileged: true, run: always` |

**Usage:**

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"
```

**Override defaults:**

User configuration takes precedence over builtin defaults:

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    run: once            # Override default (always -> once)
    privileged: false    # Override default (true -> false)
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"
```

**Required environment variables:**

Each builtin provision may require specific environment variables:

| Provision                     | Required Variables       |
|-------------------------------|--------------------------|
| `radp:nfs/external-nfs-mount` | `NFS_SERVER`, `NFS_ROOT` |

#### User Provisions

You can define your own reusable provisions with the `user:` prefix. User provisions work like builtin provisions but are defined in your project.

**Directory structure:**

After running `radp-vf init`, your project will have:

```
myproject/
└── config/
    ├── vagrant.yaml
    ├── vagrant-{env}.yaml
    └── provisions/
        ├── definitions/
        │   └── example.yaml      # Provision definition
        └── scripts/
            └── example.sh        # Provision script
```

**Subdirectory support:**

You can organize provisions into subdirectories. The subdirectory path becomes part of the provision name:

```
provisions/
├── definitions/
│   ├── example.yaml              # -> user:example
│   ├── nfs/
│   │   └── external-mount.yaml   # -> user:nfs/external-mount
│   └── docker/
│       └── setup.yaml            # -> user:docker/setup
└── scripts/
    ├── example.sh
    ├── nfs/
    │   └── external-mount.sh     # Mirror definitions structure
    └── docker/
        └── setup.sh
```

**Creating a user provision:**

1. Create a definition file in `provisions/definitions/`:

```yaml
# config/provisions/definitions/docker/setup.yaml
description: Install and configure Docker
defaults:
  privileged: true
  run: once
required_env:
  - DOCKER_VERSION
script: setup.sh    # Script in provisions/scripts/docker/setup.sh
```

2. Create the script in `provisions/scripts/` (mirroring the subdirectory structure):

```bash
#!/usr/bin/env bash
# config/provisions/scripts/docker/setup.sh
set -euo pipefail

echo "[INFO] Installing Docker ${DOCKER_VERSION}"
# Installation logic here...
```

3. Use it in your YAML config:

```yaml
provisions:
  - name: user:docker/setup
    enabled: true
    env:
      DOCKER_VERSION: "24.0"
```

**Path resolution:**

User provisions use the same two-level path resolution as regular provisions:

```
Search order:
1. {config_dir}/provisions/definitions/xxx.yaml
2. {project_root}/provisions/definitions/xxx.yaml
```

If the same provision exists in both locations, `config_dir` takes precedence and a warning is displayed.

<details>
<summary><b>All provision options</b></summary>

| Option        | Type         | Default              | Description                                               |
|---------------|--------------|----------------------|-----------------------------------------------------------|
| `name`        | string       | -                    | Provision name                                            |
| `enabled`     | boolean      | `true`               | Enable this provision                                     |
| `type`        | string       | `shell`              | Provision type: `shell` or `file`                         |
| `privileged`  | boolean      | `false`              | Run as root                                               |
| `run`         | string       | `once`               | When to run: `once`, `always`, `never`                    |
| `phase`       | string       | `pre`                | Execution phase: `pre` or `post` (common provisions only) |
| `inline`      | string       | -                    | Inline script content                                     |
| `path`        | string       | -                    | External script path                                      |
| `args`        | string/array | -                    | Script arguments                                          |
| `env`         | hash         | -                    | Environment variables                                     |
| `before`      | string       | -                    | Run before specified provision                            |
| `after`       | string       | -                    | Run after specified provision                             |
| `keep-color`  | boolean      | `false`              | Preserve color output                                     |
| `upload-path` | string       | `/tmp/vagrant-shell` | Script upload path on guest                               |
| `reboot`      | boolean      | `false`              | Reboot after execution                                    |
| `reset`       | boolean      | `false`              | Reset SSH connection after execution                      |
| `sensitive`   | boolean      | `false`              | Hide output (for sensitive data)                          |
| `binary`      | boolean      | `false`              | Transfer script as binary (no line ending conversion)     |

**File provisioner options:**

| Option        | Type   | Description               |
|---------------|--------|---------------------------|
| `source`      | string | Source file path on host  |
| `destination` | string | Destination path on guest |

</details>

### Triggers

Note: The `on` key must be quoted in YAML to prevent parsing as boolean.

```yaml
triggers:
  - name: before-up               # Trigger name
    desc: 'Pre-start trigger'     # Description
    enabled: true
    "on": before                  # before or after (must be quoted!)
    type: action                  # action, command, hook
    action: # Actions to trigger on
      - up
      - reload
    only-on: # Filter guests (supports regex)
      - '/node-.*/'
    run:
      inline: |                   # Local script
        echo "Starting..."
    # Or run-remote for guest execution
```

<details>
<summary><b>All trigger options</b></summary>

| Option     | Type         | Default  | Description                                                      |
|------------|--------------|----------|------------------------------------------------------------------|
| `name`     | string       | -        | Trigger name                                                     |
| `enabled`  | boolean      | `true`   | Enable this trigger                                              |
| `"on"`     | string       | `before` | Timing: `before` or `after` (must be quoted in YAML!)            |
| `type`     | string       | `action` | Scope: `action`, `command`, or `hook`                            |
| `action`   | string/array | `[:up]`  | Actions/commands to trigger on (e.g., `up`, `destroy`, `reload`) |
| `only-on`  | string/array | -        | Filter by machine name; supports regex `/pattern/`               |
| `ignore`   | string/array | -        | Actions to ignore                                                |
| `on-error` | string       | -        | Error behavior: `:halt`, `:continue`                             |
| `abort`    | boolean      | `false`  | Abort Vagrant operation if trigger fails                         |
| `desc`     | string       | -        | Description/info message displayed before trigger runs           |
| `info`     | string       | -        | Alias for `desc`                                                 |
| `warn`     | string       | -        | Warning message displayed before trigger runs                    |

**Run options (local execution):**

| Option   | Type         | Description                  |
|----------|--------------|------------------------------|
| `inline` | string       | Inline script to run on host |
| `path`   | string       | Script path on host          |
| `args`   | string/array | Arguments to pass to script  |

**Run-remote options (guest execution):**

| Option   | Type         | Description                             |
|----------|--------------|-----------------------------------------|
| `inline` | string       | Inline script to run on guest           |
| `path`   | string       | Script path on host (uploaded to guest) |
| `args`   | string/array | Arguments to pass to script             |

</details>

## Configuration Inheritance

The framework supports two levels of configuration merging:

### File-Level Merging

`vagrant.yaml` (base) + `vagrant-{env}.yaml` (environment) are deep merged:

| Type        | Merge Behavior                                 |
|-------------|------------------------------------------------|
| Scalars     | Override (env wins)                            |
| Hashes      | Deep merge                                     |
| Arrays      | Concatenate                                    |
| **Plugins** | **Merge by name** (env extends/overrides base) |

**Plugin merge example:**

```yaml
# vagrant.yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      manage_host: true
      manage_guest: true

# vagrant-dev.yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      ip_resolver:
        enabled: true
        execute: "hostname -I | awk '{print $2}'"
        regex: "^(\\S+)"

# Result (merged by name)
plugins:
  - name: vagrant-hostmanager
    required: true                # inherited from base
    options:
      manage_host: true           # inherited from base
      manage_guest: true          # inherited from base
      provisioner: enabled        # added from env
      ip_resolver: { ... }        # added from env
```

### Guest-Level Inheritance

Within a config file, guest settings inherit from: **global common → cluster common → guest**

| Config                           | Merge Behavior                                                                      |
|----------------------------------|-------------------------------------------------------------------------------------|
| box, provider, network, hostname | Deep merge (guest overrides)                                                        |
| hostmanager                      | Deep merge (guest overrides)                                                        |
| provisions                       | Phase-aware concat: `global-pre → cluster-pre → guest → cluster-post → global-post` |
| triggers                         | Concatenate                                                                         |
| synced-folders                   | Concatenate                                                                         |

**Example:**

```
Global common:
  - provisions: [A(pre), D(post)]
  - synced-folders: [X]

Cluster common:
  - provisions: [B(pre), E(post)]
  - synced-folders: [Y]

Guest:
  - provisions: [C]

Result for guest:
  - provisions: [A, B, C, E, D]   # global-pre, cluster-pre, guest, cluster-post, global-post
  - synced-folders: [X, Y]        # concatenated
```

### Summary Table

| Config Item    | File Merge (base + env) | Guest Inheritance (common → guest) |
|----------------|-------------------------|------------------------------------|
| plugins        | Merge by name           | N/A (global only)                  |
| box            | Deep merge              | Deep merge                         |
| provider       | Deep merge              | Deep merge                         |
| network        | Deep merge              | Deep merge                         |
| hostname       | Override                | Override                           |
| hostmanager    | Deep merge              | Deep merge                         |
| provisions     | Concatenate             | Phase-aware concatenate            |
| triggers       | Concatenate             | Concatenate                        |
| synced-folders | Concatenate             | Concatenate                        |

## Convention-Based Defaults

The framework applies sensible defaults based on context:

| Field               | Default Value                | Example                 |
|---------------------|------------------------------|-------------------------|
| `hostname`          | `{guest-id}.{cluster}.{env}` | `node-1.my-cluster.dev` |
| `provider.name`     | `{env}-{cluster}-{guest-id}` | `dev-my-cluster-node-1` |
| `provider.group-id` | `{env}/{cluster}`            | `dev/my-cluster`        |

## Validation Rules

The framework validates configurations and will raise errors for:

- **Duplicate cluster names**: No two clusters in the same environment file can have the same name
- **Duplicate guest IDs**: No two guests within the same cluster can have the same ID
- **Clusters in base config**: Clusters must be defined in `vagrant-{env}.yaml`, not in base `vagrant.yaml`

## Machine Naming

Vagrant machine names use `provider.name` (default: `{env}-{cluster}-{guest-id}`) to ensure uniqueness in
`$VAGRANT_DOTFILE_PATH/machines/<name>`. This prevents conflicts when multiple clusters have guests with the same ID.

## Environment Variables

| Variable                  | Description                                      |
|---------------------------|--------------------------------------------------|
| `RADP_VF_HOME`            | Framework installation directory (auto-detected) |
| `RADP_VAGRANT_CONFIG_DIR` | Configuration directory path                     |
| `RADP_VAGRANT_ENV`        | Override environment name                        |

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
    MyPlugin # Add here
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

## CI

### How to release

1. Trigger `release-prep` with a `bump_type` (patch/minor/major/manual, default patch). For manual, provide `vX.Y.Z`.
   This updates `version.rb` and adds a changelog entry (branch `workflow/vX.Y.Z` + PR).
2. Review/edit the changelog in the PR and merge to `main`.
3. All subsequent workflows run automatically in sequence:
    - `create-version-tag` → creates and pushes the Git tag
    - `release` → creates GitHub Release with archives
    - `update-homebrew-tap` → updates the Homebrew formula

```
release-prep (manual)
       │
       ▼
   PR merged
       │
       ▼
create-version-tag
       │
       ├──────────────┐
       ▼              ▼
   release    update-homebrew-tap
```

### GitHub Actions

#### CI (`ci.yml`)

- **Trigger:** Push/PR to `main`.
- **Purpose:** Validate Ruby syntax, test framework loading, config loading, and Vagrantfile generation across multiple
  Ruby versions (3.1-3.3) on Ubuntu and macOS.

#### Release prep (`release-prep.yml`)

- **Trigger:** Manual (`workflow_dispatch`) on `main`.
- **Purpose:** Create a release branch (`workflow/vX.Y.Z`) from the resolved version (patch/minor/major bump, or manual
  `vX.Y.Z`), update `version.rb`, insert a changelog entry, and open a PR for review.

#### Create version tag (`create-version-tag.yml`)

- **Trigger:** Manual (`workflow_dispatch`) on `main`, or merge of a `workflow/vX.Y.Z` PR.
- **Purpose:** Read version from `version.rb`, validate the changelog entry, then create/push the Git tag if it does not
  already exist.

#### Release (`release.yml`)

- **Trigger:** Successful completion of `create-version-tag`, push of a version tag (`v*`), or manual (
  `workflow_dispatch`).
- **Purpose:** Create GitHub Release with tar.gz and zip archives, extracting changelog for release notes.

#### Update Homebrew tap (`update-homebrew-tap.yml`)

- **Trigger:** Successful completion of `create-version-tag`, push of a version tag (`v*`), or manual (
  `workflow_dispatch`).
- **Purpose:** Update the Homebrew tap formula using the template from `packaging/homebrew/radp-vagrant-framework.rb`
  with the new version and SHA256.

## License

MIT
