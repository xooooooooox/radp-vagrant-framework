# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RADP Vagrant Framework is a YAML-driven framework for managing multi-machine Vagrant environments. It provides
declarative configuration for VM clusters, networks, storage, and provisioning through a modular Ruby architecture.

## Key Commands

### CLI (radp-vf)

```bash
radp-vf init myproject              # Initialize project
radp-vf init -c /path/to/config     # Initialize at specific path
radp-vf init myproject --template k8s-cluster
radp-vf list                        # List clusters and guests
radp-vf list --status               # List with VM runtime status
radp-vf -c /path list               # Use specific config directory
radp-vf validate                    # Validate YAML
radp-vf dump-config                 # Dump merged config
radp-vf dump-config -f yaml         # Output as YAML
radp-vf generate                    # Generate standalone Vagrantfile
radp-vf upgrade                     # Upgrade radp-vf to the latest version
radp-vf upgrade --check             # Check for available updates
radp-vf vg status                   # Vagrant status
radp-vf vg up -C my-cluster         # Start cluster
radp-vf vg up -C my-cluster -G 1,2  # Start specific guests
```

### Global Options

Available for all commands:

```bash
radp-vf -c, --config <dir>   # Configuration directory
radp-vf -e, --env <name>     # Override environment name
```

Options can be placed before or after the command:

```bash
radp-vf -c /path list        # Before command
radp-vf list -c /path        # After command
radp-vf -c /path -e dev vg status  # Multiple global options
```

### Vagrant Commands

```bash
cd src/main/ruby
vagrant validate
vagrant status
vagrant up local-cluster-1-guest-1
```

## Architecture

### Entry Points

- **CLI**: `bin/radp-vf` (thin ~15-line script using radp-bash-framework)
- **Vagrant**: `src/main/ruby/Vagrantfile`

### Configuration Flow

```
ConfigLoader (YAML multi-file)
    ↓
ConfigMerger (global → cluster → guest)
    ↓
RadpVagrant (orchestrates)
    ↓
Configurators (apply to Vagrant)
```

### Key Directories

| Directory                                       | Purpose               |
|-------------------------------------------------|-----------------------|
| `src/main/shell/commands/`                      | CLI commands          |
| `src/main/shell/libs/vf/`                       | Shell libraries       |
| `src/main/ruby/lib/radp_vagrant/`               | Ruby modules          |
| `src/main/ruby/lib/radp_vagrant/configurators/` | Vagrant configurators |
| `src/main/ruby/lib/radp_vagrant/provisions/`    | Builtin provisions    |
| `src/main/ruby/lib/radp_vagrant/triggers/`      | Builtin triggers      |
| `templates/`                                    | Project templates     |

## Configuration Structure

```yaml
radp:
  env: dev
  extend:
    vagrant:
      plugins:
        - name: vagrant-hostmanager
          options: { ... }
      config:
        common:                    # Global settings
          provisions: [ ... ]
          triggers: [ ... ]
        clusters:
          - name: my-cluster
            common: { ... }        # Cluster settings
            guests:
              - id: node-1
                hostname: ...
                provider: { ... }
                network: { ... }
```

## Naming Conventions

### Convention-Based Defaults

| Field               | Default Value                |
|---------------------|------------------------------|
| `hostname`          | `{guest-id}.{cluster}.{env}` |
| `provider.name`     | `{env}-{cluster}-{guest-id}` |
| `provider.group-id` | `{env}/{cluster}`            |

### Provisions/Triggers Prefixes

| Prefix  | Source                 |
|---------|------------------------|
| `radp:` | Builtin (framework)    |
| `user:` | User-defined (project) |

## Key Design Decisions

1. **Array Concatenation**: provisions, triggers, synced-folders accumulate
2. **Plugin Merge by Name**: Same-named plugins have options deep merged
3. **Provisions Phase**: `phase: pre|post` controls execution order
4. **Clusters in Env Files Only**: Clusters must be in `{base}-{env}.yaml`
5. **Machine Naming**: Uses `{env}-{cluster}-{id}` for uniqueness

## Environment Variables

| Variable                  | Description                      |
|---------------------------|----------------------------------|
| `RADP_VF_HOME`            | Framework installation directory |
| `RADP_VAGRANT_CONFIG_DIR` | Configuration directory          |
| `RADP_VAGRANT_ENV`        | Override environment name        |

## Code Style

- Ruby: frozen_string_literal, 2-space indent, snake_case
- YAML: 2-space indent, dash-case for keys
- Triggers: `"on"` must be quoted (YAML parses bare `on` as boolean)

## CI/CD Workflows

| Workflow                  | Purpose               |
|---------------------------|-----------------------|
| `ci.yml`                  | Run tests             |
| `release-prep.yml`        | Create release branch |
| `build-copr-package.yml`  | COPR build            |
| `build-obs-package.yml`   | OBS build             |
| `update-homebrew-tap.yml` | Update Homebrew       |

## See Also

- [docs/developer/architecture.md](docs/developer/architecture.md) - Detailed architecture
- [docs/configuration.md](docs/configuration.md) - Full configuration reference
- [docs/developer/extending.md](docs/developer/extending.md) - Add plugins, provisions, triggers
- [AGENTS.md](AGENTS.md) - Multi-agent guidelines
