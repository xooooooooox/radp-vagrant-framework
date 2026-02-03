# AGENTS.md

Guidelines for multi-agent collaboration when working on radp-vagrant-framework.

## Project Overview

RADP Vagrant Framework is a YAML-driven framework for managing multi-machine Vagrant environments. It provides
declarative configuration for VM clusters, networks, storage, and provisioning through a modular Ruby architecture.

## Agent Roles

### Code Agent

Handles Ruby and Shell code modifications:

- **Ruby modules**: `src/main/ruby/lib/radp_vagrant/`
- **Shell commands**: `src/main/shell/commands/`
- **Shell libraries**: `src/main/shell/libs/vf/`

### Config Agent

Handles configuration and templates:

- **YAML configs**: `src/main/ruby/config/`
- **Templates**: `templates/`
- **Provision definitions**: `src/main/ruby/lib/radp_vagrant/provisions/definitions/`
- **Trigger definitions**: `src/main/ruby/lib/radp_vagrant/triggers/definitions/`

### Test Agent

Handles testing:

- **Shell tests**: `tests/`
- Run with: `./tests/run_tests.sh`

### Docs Agent

Handles documentation:

- **User docs**: `docs/`
- **Developer docs**: `docs/developer/`
- **Reference docs**: `docs/reference/`

## Key Conventions

### Naming

| Type                | Convention                   | Example                 |
|---------------------|------------------------------|-------------------------|
| Ruby files          | snake_case                   | `config_loader.rb`      |
| Shell files         | snake_case                   | `ruby_bridge.sh`        |
| YAML keys           | dash-case                    | `synced-folders`        |
| Provisions/Triggers | `{prefix}:{category}/{name}` | `radp:time/chrony-sync` |

### Prefixes

| Prefix  | Source                 |
|---------|------------------------|
| `radp:` | Builtin (framework)    |
| `user:` | User-defined (project) |

### Code Style

- Ruby: `frozen_string_literal`, 2-space indent, snake_case
- Shell: POSIX-compatible where possible, 2-space indent
- YAML: 2-space indent, dash-case keys

## File Ownership

| Path                                            | Owner        | Notes                 |
|-------------------------------------------------|--------------|-----------------------|
| `src/main/ruby/lib/radp_vagrant/`               | Code Agent   | Core Ruby modules     |
| `src/main/ruby/lib/radp_vagrant/configurators/` | Code Agent   | Vagrant configurators |
| `src/main/ruby/lib/radp_vagrant/provisions/`    | Code/Config  | Provision system      |
| `src/main/ruby/lib/radp_vagrant/triggers/`      | Code/Config  | Trigger system        |
| `src/main/shell/commands/`                      | Code Agent   | CLI commands          |
| `templates/`                                    | Config Agent | Project templates     |
| `docs/`                                         | Docs Agent   | Documentation         |
| `tests/`                                        | Test Agent   | Test files            |

## Coordination Rules

1. **Config changes**: Notify Code Agent if schema changes
2. **New provisions/triggers**: Update registry and docs
3. **CLI changes**: Update shell completion if commands change
4. **Breaking changes**: Update CHANGELOG.md

## Common Tasks

### Adding a Builtin Provision

1. Create definition: `provisions/definitions/{category}/{name}.yaml`
2. Create script: `provisions/scripts/{category}/{name}.sh`
3. Update docs: `docs/reference/builtin-provisions.md`

### Adding a Builtin Trigger

1. Create definition: `triggers/definitions/{category}/{name}.yaml`
2. Create script: `triggers/scripts/{category}/{name}.sh`
3. Update docs: `docs/reference/builtin-triggers.md`

### Adding a CLI Command

1. Create command: `src/main/shell/commands/{name}.sh`
2. Add annotations: `@cmd`, `@desc`, `@option`, etc.
3. Update docs: `docs/reference/cli-reference.md`

## See Also

- [CLAUDE.md](./CLAUDE.md) - AI assistant guidelines
- [Architecture](docs/developer/architecture.md) - Detailed architecture
- [Extending](docs/developer/extending.md) - How to extend the framework
