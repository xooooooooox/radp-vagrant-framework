# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RADP Vagrant Framework is a YAML-driven framework for managing multi-machine Vagrant environments. It provides declarative configuration for VM clusters, networks, storage, and provisioning through a modular Ruby architecture.

## Key Commands

### CLI (radp-vf)
```bash
# Show help
./bin/radp-vf help

# Initialize a project (uses 'base' template by default)
./bin/radp-vf init myproject

# Initialize with a specific template
./bin/radp-vf init myproject --template k8s-cluster

# Initialize with template variables
./bin/radp-vf init myproject --template k8s-cluster \
  --set cluster_name=homelab \
  --set worker_count=3

# List available templates
./bin/radp-vf template list

# Show template details
./bin/radp-vf template show k8s-cluster

# List clusters and guests
./bin/radp-vf list
./bin/radp-vf -e prod list
./bin/radp-vf list -v                    # Verbose mode (all details)
./bin/radp-vf list -v node-1             # Verbose for specific guest
./bin/radp-vf list --provisions          # Show provisions only
./bin/radp-vf list --synced-folders      # Show synced folders only
./bin/radp-vf list --triggers            # Show triggers only

# Validate YAML configuration
./bin/radp-vf validate

# Dump merged configuration
./bin/radp-vf dump-config
./bin/radp-vf dump-config -f yaml
./bin/radp-vf dump-config -o config.json
./bin/radp-vf dump-config -f yaml -o config.yaml
./bin/radp-vf dump-config node-1

# Generate standalone Vagrantfile
./bin/radp-vf generate
./bin/radp-vf generate Vagrantfile.standalone

# Run vagrant commands
./bin/radp-vf vg status
./bin/radp-vf -c /path/to/config -e prod vg up

# Global options
# -c, --config <dir>   Configuration directory
# -e, --env <name>     Override environment
# -v, --verbose        Enable verbose output
# -h, --help           Show help
# --version            Show version
```

### Vagrant Commands
```bash
cd src/main/ruby

# Validate Vagrant configuration
vagrant validate

# Show VM status
vagrant status

# Start VMs (use machine_name: <env>-<cluster>-<guest-id>)
vagrant up
vagrant up local-cluster-1-guest-1
```

### Ruby API (for debugging)
```bash
cd src/main/ruby

# Dump merged configuration (JSON format)
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"

# Filter by guest_id or machine_name
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', 'guest-1')"

# Output as YAML
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', nil, format: :yaml)"

# Generate standalone Vagrantfile
ruby -r ./lib/radp_vagrant -e "puts RadpVagrant.generate_vagrantfile('config')"
```

## Architecture

### Entry Point
- `src/main/ruby/Vagrantfile` - Vagrant entry point that loads RadpVagrant module

### Configuration Flow
1. **ConfigLoader** (`lib/radp_vagrant/config_loader.rb`) loads YAML with multi-file support:
   - Base config: `config/vagrant.yaml` (must contain `radp.env`)
   - Environment config: `config/vagrant-{env}.yaml`
   - Deep merge with array concatenation
   - **Plugins merge by name** (same-named plugins have options deep merged)

2. **ConfigMerger** (`lib/radp_vagrant/config_merger.rb`) handles three-level inheritance:
   - Global common → Cluster common → Guest
   - Arrays concatenate, hashes merge, scalars override
   - Provisions support `phase: pre|post` for execution order control

3. **RadpVagrant** (`lib/radp_vagrant.rb`) orchestrates:
   - Plugin configuration
   - Cluster/guest processing
   - Convention-based defaults (hostname, provider.name, provider.group-id)

4. **Configurators** (`lib/radp_vagrant/configurators/`) apply settings to Vagrant:
   - `box.rb` - Box settings
   - `provider.rb` - Provider registry (VirtualBox, extensible)
   - `network.rb` - Hostname, private/public networks, port forwarding
   - `hostmanager.rb` - Per-guest hostmanager (aliases, ip-resolver)
   - `synced_folder.rb` - Synced folders (basic, nfs, rsync, smb)
   - `provision.rb` - Shell/file provisioners
   - `trigger.rb` - Before/after triggers with regex filtering
   - `plugin.rb` - Plugin orchestrator

5. **CLI Module** (`lib/radp_vagrant/cli/`) provides command implementations:
   - `base.rb` - Base class with common helpers (formatting, config loading)
   - `list.rb` - List command with compact/verbose views
   - `validate.rb` - Validate command for config verification
   - `dump_config.rb` - Dump-config command for exporting merged configuration (JSON/YAML)
   - `generate.rb` - Generate command for standalone Vagrantfile generation
   - `info.rb` - Info command for displaying environment and configuration information
   - `template.rb` - Template command for listing and showing templates

### Modular Plugin System
Plugin configurators are modularized under `lib/radp_vagrant/configurators/plugins/`:
- `base.rb` - Base class with helper methods
- `registry.rb` - Plugin discovery and lookup
- `hostmanager.rb` - vagrant-hostmanager
- `vbguest.rb` - vagrant-vbguest
- `proxyconf.rb` - vagrant-proxyconf
- `bindfs.rb` - vagrant-bindfs

To add a new plugin:
1. Create `plugins/my_plugin.rb` inheriting from `Plugins::Base`
2. Implement `.plugin_name` and `.configure` methods
3. Add class to `registry.rb` `plugin_classes` array

### Builtin Provisions System
Builtin provisions are framework-provided provisions under `lib/radp_vagrant/provisions/`:
- `registry.rb` - Central registry with auto-discovery from YAML definitions
- `definitions/**/*.yaml` - Provision metadata (desc, defaults with env and script)
- `scripts/**/*.sh` - Implementation scripts
- Supports subdirectories with path naming: `definitions/nfs/mount.yaml` → `radp:nfs/mount`

Provision definition format:
```yaml
desc: Human-readable description
defaults:
  privileged: true
  run: once
  env:
    required:
      - name: REQ_VAR
        desc: Required variable description
    optional:
      - name: OPT_VAR
        value: "default_value"
        desc: Optional variable description
  script: script-name.sh
```

Builtin provisions use `radp:` prefix (e.g., `radp:nfs/external-nfs-mount`). User config merges with definition defaults (user values take precedence).

To add a new builtin provision:
1. Create `definitions/my-provision.yaml` (or `definitions/category/my-provision.yaml` for subdirectory)
2. Create `scripts/my-provision.sh` (or `scripts/category/my-provision.sh` for subdirectory)
3. Registry auto-discovers from YAML files recursively (no code changes needed)

### User Provisions System
User provisions are project-defined provisions under `{config_dir}/provisions/` or `{project_root}/provisions/`:
- `user_registry.rb` - Registry for user provisions with two-level path lookup
- User provisions use `user:` prefix (e.g., `user:docker-setup` or `user:nfs/external-mount`)
- Supports subdirectories with path naming: `definitions/nfs/mount.yaml` → `user:nfs/mount`
- Scripts mirror definitions structure: `scripts/nfs/mount.sh`

Path resolution (consistent with script path resolution):
1. `{config_dir}/provisions/definitions/xxx.yaml`
2. `{project_root}/provisions/definitions/xxx.yaml`
If found in both, config_dir takes precedence with a warning.

### Builtin Triggers System
Builtin triggers are framework-provided triggers under `lib/radp_vagrant/triggers/`:
- `registry.rb` - Central registry with auto-discovery from YAML definitions
- `definitions/**/*.yaml` - Trigger metadata (desc, defaults with timing, action, run/run-remote)
- `scripts/**/*.sh` - Implementation scripts
- Supports subdirectories with path naming: `definitions/system/disable-swap.yaml` → `radp:system/disable-swap`

Trigger definition format:
```yaml
desc: Human-readable description
defaults:
  "on": after           # timing: before/after
  action:               # trigger actions (single or array)
    - up
    - reload
  type: action          # trigger type: action/command/hook
  on-error: continue    # error handling: continue/halt
  run-remote:           # execute on guest (or use 'run' for host)
    script: script-name.sh
```

Builtin triggers use `radp:` prefix (e.g., `radp:system/disable-swap`). User config merges with definition defaults (user values take precedence).

Available builtin triggers:
- `radp:system/disable-swap` - Disable swap partition (required for Kubernetes)
- `radp:system/disable-selinux` - Disable SELinux (set to permissive mode)
- `radp:system/disable-firewalld` - Disable firewalld service

To add a new builtin trigger:
1. Create `definitions/my-trigger.yaml` (or `definitions/category/my-trigger.yaml` for subdirectory)
2. Create `scripts/my-trigger.sh` (or `scripts/category/my-trigger.sh` for subdirectory)
3. Registry auto-discovers from YAML files recursively (no code changes needed)

### Template System
Templates allow users to initialize projects from predefined configurations with variable substitution.

**Template locations:**
- Builtin templates: `$RADP_VF_HOME/templates/`
- User templates: `~/.config/radp-vagrant/templates/`

**Template structure:**
```
templates/
├── base/                      # Template name
│   ├── template.yaml          # Template metadata
│   └── files/                 # Files to copy
│       ├── config/
│       │   ├── vagrant.yaml
│       │   └── vagrant-{{env}}.yaml
│       └── provisions/
│           ├── definitions/
│           └── scripts/
```

**Template metadata format (`template.yaml`):**
```yaml
name: my-template
desc: Human-readable description
version: 1.0.0
variables:
  - name: env
    desc: Environment name
    default: dev
    required: true
  - name: cluster_name
    desc: Name of the cluster
    default: example
  - name: mem
    desc: Memory allocation in MB
    default: 2048
    type: integer
```

**Variable substitution:**
- Use `{{variable}}` syntax in file contents and filenames
- Example: `vagrant-{{env}}.yaml` becomes `vagrant-dev.yaml` when `env=dev`

**Available builtin templates:**
- `base` - Minimal template for getting started
- `single-node` - Enhanced single VM with common provisions
- `k8s-cluster` - Multi-node Kubernetes cluster

**To create a custom template:**
1. Create directory under `~/.config/radp-vagrant/templates/my-template/`
2. Create `template.yaml` with metadata and variables
3. Create `files/` directory with template files
4. Use `{{variable}}` placeholders in files and filenames
5. Run `radp-vf template list` to verify discovery

### Path Resolution
All relative paths use unified two-level resolution via `PathResolver`:
- `{config_dir}/path` (first priority)
- `{project_root}/path` (fallback)
Applies to: provision `path`, file `source`, user provision definitions

## Directory Structure

```
bin/
└── radp-vf                         # CLI entry point
completions/
├── radp-vf.bash                    # Bash completion
└── radp-vf.zsh                     # Zsh completion
install.sh                          # Installation script
templates/                          # Builtin project templates
├── base/                           # Minimal getting-started template
│   ├── template.yaml               # Template metadata
│   └── files/                      # Template files
├── single-node/                    # Enhanced single VM template
└── k8s-cluster/                    # Kubernetes cluster template
src/main/ruby/
├── Vagrantfile                     # Vagrant entry point
├── config/
│   ├── vagrant.yaml                # Base config (sets env)
│   ├── vagrant-sample.yaml         # Sample environment clusters
│   └── vagrant-local.yaml          # Local environment clusters
└── lib/
    ├── radp_vagrant.rb             # Main coordinator
    └── radp_vagrant/
        ├── config_loader.rb        # Multi-file YAML loading
        ├── config_merger.rb        # Deep merge with array concatenation
        ├── path_resolver.rb        # Unified two-level path resolution
        ├── cli/                    # CLI command implementations
        │   ├── base.rb             # Base class with common helpers
        │   ├── list.rb             # List command
        │   ├── validate.rb         # Validate command
        │   └── template.rb         # Template list/show command
        ├── templates/              # Template system
        │   ├── registry.rb         # Template discovery
        │   └── renderer.rb         # Variable substitution
        ├── configurators/
        │   ├── box.rb
        │   ├── provider.rb
        │   ├── network.rb
        │   ├── hostmanager.rb
        │   ├── synced_folder.rb
        │   ├── provision.rb
        │   ├── trigger.rb
        │   ├── plugin.rb
        │   └── plugins/
        │       ├── base.rb
        │       ├── registry.rb
        │       ├── hostmanager.rb
        │       ├── vbguest.rb
        │       ├── proxyconf.rb
        │       └── bindfs.rb
        ├── provisions/             # Builtin provisions
        │   ├── registry.rb         # Builtin provisions registry
        │   ├── user_registry.rb    # User provisions registry
        │   ├── definitions/        # YAML definitions
        │   └── scripts/            # Shell scripts
        └── triggers/               # Builtin triggers
            ├── registry.rb         # Builtin triggers registry
            ├── definitions/        # YAML definitions
            └── scripts/            # Shell scripts
```

## Configuration Structure

```yaml
radp:
  env: dev                          # Determines which env file to load
  extend:
    vagrant:
      plugins:
        - name: vagrant-hostmanager
          required: true            # Auto-install if missing
          options:
            enabled: true
            manage_host: true
      config:
        common:                     # Global settings (inherited by all)
          provisions: [...]
          triggers: [...]
          synced-folders:
            basic: [...]
        clusters:
          - name: my-cluster
            common:                 # Cluster settings (inherited by guests)
              box: { name: ... }
            guests:
              - id: node-1
                hostname: ...       # Convention default: {id}.{cluster}.{env}
                hostmanager:
                  aliases: [...]
                provider:
                  name: ...         # Convention default: {env}-{cluster}-{id}
                  group-id: ...     # Convention default: {env}/{cluster}
                network: { ... }
                provisions: [...]
```

## Environment Variables

- `RADP_VF_HOME` - Framework installation directory (auto-detected: project root for git clone, libexec for Homebrew)
- `RADP_VAGRANT_CONFIG_DIR` - Override configuration directory path
- `RADP_VAGRANT_ENV` - Override environment name

## Code Style

- Ruby: frozen_string_literal, 2-space indent, snake_case
- YAML: 2-space indent, dash-case for keys (except plugin options use underscore)
- Triggers: `"on"` key must be quoted (YAML parses bare `on` as boolean)

## Key Design Decisions

1. **Array Concatenation**: provisions, triggers, synced-folders accumulate across inheritance levels
2. **Plugin Merge by Name**: Same-named plugins in base and env files have their options deep merged (env extends/overrides base)
3. **Provisions Phase**: Common provisions support `phase: pre|post` for execution order (global-pre → cluster-pre → guest → cluster-post → global-post)
4. **Convention-Based Defaults**: hostname, provider.name, provider.group-id auto-generated
5. **Plugin Options**: Use underscores to match official Vagrant plugin documentation
6. **Modular Plugins**: Each plugin configurator in separate file for maintainability
7. **Machine Naming**: Vagrant machine name uses `provider.name` (default: `{env}-{cluster}-{id}`) for uniqueness in `$VAGRANT_DOTFILE_PATH/machines/<name>`
8. **Clusters Only in Env Files**: Clusters must be defined in `vagrant-{env}.yaml`, not in base `vagrant.yaml`
9. **Hybrid Bash/Ruby Architecture**: CLI entry point (`bin/radp-vf`) is Bash for option parsing and environment setup; complex logic is in Ruby modules (`lib/radp_vagrant/cli/`)

## Validation Rules

- Duplicate cluster names in the same env file are not allowed
- Duplicate guest IDs within the same cluster are not allowed
- Clusters cannot be defined in base `vagrant.yaml` (only in `vagrant-{env}.yaml`)
