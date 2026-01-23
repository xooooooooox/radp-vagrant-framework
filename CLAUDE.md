# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RADP Vagrant Framework is a YAML-driven framework for managing multi-machine Vagrant environments. It provides declarative configuration for VM clusters, networks, storage, and provisioning through a modular Ruby architecture.

## Key Commands

```bash
cd src/main/ruby

# Validate Vagrant configuration
vagrant validate

# Show VM status
vagrant status

# Start VMs (use machine_name: <env>-<cluster>-<guest-id>)
vagrant up
vagrant up local-cluster-1-guest-1

# Debug: dump merged configuration (JSON format)
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"

# Filter by guest_id or machine_name
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', 'guest-1')"
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', 'local-cluster-1-guest-1')"

# Output as YAML
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', nil, format: :yaml)"

# Generate standalone Vagrantfile (dry-run preview)
ruby -r ./lib/radp_vagrant -e "puts RadpVagrant.generate_vagrantfile('config')"

# Generate and save to file
ruby -r ./lib/radp_vagrant -e "RadpVagrant.generate_vagrantfile('config', 'Vagrantfile.generated')"
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
- `definitions/*.yaml` - Provision metadata (description, defaults, required_env, script)
- `scripts/*.sh` - Implementation scripts

Builtin provisions use `radp:` prefix (e.g., `radp:synology-nfs`). User config merges with definition defaults (user values take precedence).

To add a new builtin provision:
1. Create `definitions/my-provision.yaml` with description, defaults, required_env, script
2. Create `scripts/my-provision.sh` implementation
3. Registry auto-discovers from YAML files (no code changes needed)

## Directory Structure

```
src/main/ruby/
├── Vagrantfile                     # Entry point
├── config/
│   ├── vagrant.yaml                # Base config (sets env)
│   ├── vagrant-sample.yaml         # Sample environment clusters
│   └── vagrant-local.yaml          # Local environment clusters
└── lib/
    ├── radp_vagrant.rb             # Main coordinator
    └── radp_vagrant/
        ├── config_loader.rb        # Multi-file YAML loading
        ├── config_merger.rb        # Deep merge with array concatenation
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
        └── provisions/             # Builtin provisions
            ├── registry.rb         # Auto-discovery registry
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

- `RADP_VAGRANT_CONFIG_DIR` - Override configuration directory path

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

## Validation Rules

- Duplicate cluster names in the same env file are not allowed
- Duplicate guest IDs within the same cluster are not allowed
- Clusters cannot be defined in base `vagrant.yaml` (only in `vagrant-{env}.yaml`)
