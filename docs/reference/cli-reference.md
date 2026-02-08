# CLI Reference

Complete reference for `radp-vf` commands and options.

## Command Structure

```
radp-vf [framework-options] <command> [command-options] [arguments]
```

## Framework Options

| Option          | Description            |
|-----------------|------------------------|
| `-v, --verbose` | Enable verbose logging |
| `--debug`       | Enable debug logging   |
| `-h, --help`    | Show help              |
| `--version`     | Show version           |

## Commands

### init

Initialize a new project from template.

```shell
radp-vf init [dir] [options]
```

| Option                  | Description                   |
|-------------------------|-------------------------------|
| `-t, --template <name>` | Template name (default: base) |
| `--set <key=value>`     | Set template variable         |

**Examples:**

```shell
radp-vf init myproject
radp-vf init myproject --template k8s-cluster
radp-vf init myproject --template k8s-cluster --set cluster_name=homelab
```

### vg

Run vagrant commands with cluster targeting.

```shell
radp-vf vg [options] <vagrant-command> [vagrant-args]
```

| Option              | Short | Description                     |
|---------------------|-------|---------------------------------|
| `--config <dir>`    | `-c`  | Configuration directory         |
| `--env <name>`      | `-e`  | Override environment            |
| `--cluster <names>` | `-C`  | Cluster names (comma-separated) |
| `--guest-ids <ids>` | `-G`  | Guest IDs (requires --cluster)  |

**Examples:**

```shell
radp-vf vg status
radp-vf vg up
radp-vf vg -c ~/myproject/config up
radp-vf vg up -C my-cluster
radp-vf vg up -C my-cluster -G 1,2
radp-vf vg ssh dev-my-cluster-node-1
```

### list

List clusters and guests from configuration.

```shell
radp-vf list [options] [filter]
```

| Option                 | Description                    |
|------------------------|--------------------------------|
| `-c, --config <dir>`   | Configuration directory        |
| `-e, --env <name>`     | Override environment           |
| `-a, --all`            | Show all details               |
| `-p, --provisions`     | Show provisions only           |
| `-s, --synced-folders` | Show synced folders only       |
| `-t, --triggers`       | Show triggers only             |
| `-S, --status`         | Show vagrant machine status    |

**Status Icons (`--status`):**

When `--status` is used, a status indicator is shown before each machine name. In a terminal (TTY), colored
circles are displayed; when piped or redirected, text badges are used instead.

| Vagrant State | TTY    | Piped    | Meaning                  |
|---------------|--------|----------|--------------------------|
| `running`     | `●` green  | `[up]`   | VM is running            |
| `poweroff`    | `●` red    | `[off]`  | VM is powered off        |
| `aborted`     | `●` red    | `[err]`  | VM was aborted           |
| `saved`       | `●` yellow | `[save]` | VM state is saved        |
| `not_created` | `○` gray   | `[--]`   | VM has not been created  |
| unknown       | `?` gray   | `[??]`   | Status could not be read |

**Examples:**

```shell
radp-vf list
radp-vf list -a
radp-vf list -a node-1
radp-vf list -p
radp-vf list --status
radp-vf list -a --status
```

### validate

Validate YAML configuration files.

```shell
radp-vf validate [options]
```

| Option               | Description             |
|----------------------|-------------------------|
| `-c, --config <dir>` | Configuration directory |
| `-e, --env <name>`   | Override environment    |

### dump-config

Export merged configuration.

```shell
radp-vf dump-config [options] [filter]
```

| Option                | Description                         |
|-----------------------|-------------------------------------|
| `-c, --config <dir>`  | Configuration directory             |
| `-e, --env <name>`    | Override environment                |
| `-f, --format <fmt>`  | Output format: json (default), yaml |
| `-o, --output <file>` | Output file                         |

**Examples:**

```shell
radp-vf dump-config
radp-vf dump-config -f yaml
radp-vf dump-config -o config.json
radp-vf dump-config node-1
```

### generate

Generate standalone Vagrantfile.

```shell
radp-vf generate [options] [output-file]
```

| Option               | Description             |
|----------------------|-------------------------|
| `-c, --config <dir>` | Configuration directory |
| `-e, --env <name>`   | Override environment    |

**Examples:**

```shell
radp-vf generate
radp-vf generate Vagrantfile.standalone
```

### template list

List available templates.

```shell
radp-vf template list
```

### template show

Show template details.

```shell
radp-vf template show <name>
```

### info

Show environment information.

```shell
radp-vf info [options]
```

| Option               | Description             |
|----------------------|-------------------------|
| `-c, --config <dir>` | Configuration directory |
| `-e, --env <name>`   | Override environment    |

### version

Show radp-vagrant-framework version.

```shell
radp-vf version
```

### completion

Generate shell completion script.

```shell
radp-vf completion <bash|zsh>
```

## Environment Variables

| Variable                            | Description                      | Default       |
|-------------------------------------|----------------------------------|---------------|
| `RADP_VF_HOME`                      | Framework installation directory | Auto-detected |
| `RADP_VAGRANT_CONFIG_DIR`           | Configuration directory path     | `./config`    |
| `RADP_VAGRANT_ENV`                  | Override environment name        | From config   |
| `RADP_VAGRANT_CONFIG_BASE_FILENAME` | Override base config filename    | Auto-detect   |

**Priority (highest to lowest):**

```
Config dir:  -c flag > RADP_VAGRANT_CONFIG_DIR > ./config
Config file: RADP_VAGRANT_CONFIG_BASE_FILENAME > vagrant.yaml > config.yaml
Environment: -e flag > RADP_VAGRANT_ENV > radp.env in config
```

## Shell Completion

### Installation

```shell
# Bash
radp-vf completion bash > ~/.local/share/bash-completion/completions/radp-vf

# Zsh
mkdir -p ~/.zfunc
radp-vf completion zsh > ~/.zfunc/_radp-vf
```

### Dynamic Completion

The `vg` command supports dynamic completion:

- `--cluster` / `-C` - Completes cluster names
- `--guest-ids` / `-G` - Completes guest IDs for specified cluster
- Positional args - Completes vagrant commands + machine names

## See Also

- [Getting Started](../getting-started.md) - Quick start guide
- [Configuration Reference](../configuration.md) - Configuration options
