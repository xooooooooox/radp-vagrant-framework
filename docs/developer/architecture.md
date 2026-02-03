# Architecture

This document describes the internal architecture of radp-vagrant-framework.

## Entry Points

### CLI Entry (`bin/radp-vf`)

- Thin ~15-line entry script using radp-bash-framework
- Checks for radp-bf dependency, sets `RADP_APP_NAME` and `RADP_APP_ROOT`
- Delegates to `radp-bf path launcher` for command dispatch

### Vagrant Entry (`src/main/ruby/Vagrantfile`)

- Vagrant entry point that loads RadpVagrant module

## CLI Architecture (radp-bf Framework)

The CLI follows radp-bash-framework conventions:

1. **Command Discovery**: Commands auto-discovered from `src/main/shell/commands/`
    - File `commands/list.sh` → command `radp-vf list`
    - File `commands/template/list.sh` → command `radp-vf template list`

2. **Library Auto-Loading**: Libraries in `src/main/shell/libs/` are auto-sourced

3. **Command Annotations**:
   ```bash
   # @cmd
   # @desc List clusters and guests
   # @arg filter Guest ID or machine name filter
   # @option -c, --config <dir> Configuration directory
   # @meta passthrough  # For vg.sh
   ```

## Configuration Flow

```
ConfigLoader (load YAML with multi-file support)
    ↓
ConfigMerger (three-level inheritance)
    ↓
RadpVagrant (orchestrates plugins, clusters, guests)
    ↓
Configurators (apply settings to Vagrant)
```

### ConfigLoader

- Auto-detects base config: `vagrant.yaml` or `config.yaml`
- Loads environment config: `{base}-{env}.yaml`
- Deep merge with array concatenation
- Plugins merge by name

### ConfigMerger

Handles three-level inheritance:

- Global common → Cluster common → Guest
- Arrays concatenate, hashes merge, scalars override
- Provisions support `phase: pre|post` for execution order

### Configurators

Located in `lib/radp_vagrant/configurators/`:

| Configurator       | Purpose                        |
|--------------------|--------------------------------|
| `box.rb`           | Box settings                   |
| `provider.rb`      | Provider registry (VirtualBox) |
| `network.rb`       | Hostname, networks, ports      |
| `hostmanager.rb`   | Per-guest hostmanager          |
| `synced_folder.rb` | Synced folders                 |
| `provision.rb`     | Shell/file provisioners        |
| `trigger.rb`       | Before/after triggers          |
| `plugin.rb`        | Plugin orchestrator            |

## Directory Structure

```
bin/
└── radp-vf                         # CLI entry point
src/main/shell/                     # Bash CLI layer
├── commands/                       # Command auto-discovery
│   ├── list.sh
│   ├── validate.sh
│   ├── vg.sh                       # Passthrough to vagrant
│   └── template/
│       ├── list.sh
│       └── show.sh
├── config/
│   └── config.yaml
└── libs/
    └── vf/
        ├── _common.sh
        └── ruby_bridge.sh
src/main/ruby/
├── Vagrantfile
├── config/
│   ├── vagrant.yaml
│   └── vagrant-{env}.yaml
└── lib/
    ├── radp_vagrant.rb             # Main coordinator
    └── radp_vagrant/
        ├── config_loader.rb
        ├── config_merger.rb
        ├── path_resolver.rb
        ├── configurators/
        │   └── plugins/
        ├── provisions/
        │   ├── registry.rb
        │   ├── user_registry.rb
        │   ├── definitions/
        │   └── scripts/
        ├── triggers/
        │   ├── registry.rb
        │   ├── definitions/
        │   └── scripts/
        └── templates/
            ├── registry.rb
            └── renderer.rb
```

## Registry Systems

### Builtin Provisions/Triggers

- Auto-discovered from YAML definitions
- Scripts in `scripts/` directory
- `radp:` prefix (e.g., `radp:time/chrony-sync`)

### User Provisions/Triggers

- `user:` prefix (e.g., `user:docker/setup`)
- Two-level path lookup: config_dir → project_root
- Same definition format as builtin

## Path Resolution

All relative paths use unified two-level resolution via `PathResolver`:

1. `{config_dir}/path` (first priority)
2. `{project_root}/path` (fallback)

Applies to: provision `path`, file `source`, user definitions

## Key Design Decisions

1. **Array Concatenation**: provisions, triggers, synced-folders accumulate
2. **Plugin Merge by Name**: Same-named plugins have options deep merged
3. **Provisions Phase**: `phase: pre|post` controls execution order
4. **Convention-Based Defaults**: hostname, provider.name auto-generated
5. **Machine Naming**: Uses `{env}-{cluster}-{id}` for uniqueness

## See Also

- [Extending](./extending.md) - Add plugins, provisions, triggers
- [Configuration Reference](../configuration.md) - Configuration options
