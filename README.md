# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

[![GitHub Release](https://img.shields.io/github/v/release/xooooooooox/radp-vagrant-framework?label=Release)](https://github.com/xooooooooox/radp-vagrant-framework/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/ci.yml?label=CI)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/ci.yml)
[![CI: Homebrew](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/update-homebrew-tap.yml?label=Homebrew%20tap)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/update-homebrew-tap.yml)

A YAML-driven framework for managing multi-machine Vagrant environments with configuration inheritance and modular
provisioning.

## Features

- **Declarative YAML Configuration** - Define VMs, networks, provisions, and triggers in YAML
- **Multi-File Configuration** - Base config + environment-specific overrides (`vagrant.yaml` or `config.yaml` +
  `{base}-{env}.yaml`)
- **Configuration Inheritance** - Global → Cluster → Guest with automatic merging
- **Run Anywhere** - No need to `cd` to Vagrantfile directory; run commands from anywhere with `-c` flag
- **Template System** - Initialize projects from predefined templates (`base`, `single-node`, `k8s-cluster`)
- **Builtin Provisions & Triggers** - Reusable components with `radp:` prefix
- **Plugin Support** - vagrant-hostmanager, vagrant-vbguest, vagrant-proxyconf, vagrant-bindfs
- **Convention-Based Defaults** - Automatic hostname, provider name, and group-id generation
- **Debug Support** - Dump merged config, generate standalone Vagrantfile for inspection

## Prerequisites

- Ruby 2.7+
- Vagrant 2.0+
- VirtualBox (or other supported provider)

## Installation

### Homebrew (Recommended)

```shell
brew tap xooooooooox/radp
brew install radp-vagrant-framework
```

### Script (curl)

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh
| bash
```

Install from a specific branch or tag:

```shell
bash install.sh --ref main
bash install.sh --ref v1.0.0-rc1
```

See [Installation Guide](docs/installation.md) for more options (manual install, upgrade, shell completion).

### Recommended: Use homelabctl

For a more feature-rich CLI experience, consider [homelabctl](https://github.com/xooooooooox/homelabctl):

```shell
brew tap xooooooooox/radp
brew install homelabctl

homelabctl vf init myproject
homelabctl vg status
```

## Quick Start

### 1. Initialize a Project

```shell
# Default template
radp-vf init myproject

# With specific template
radp-vf init myproject --template k8s-cluster

# With variables
radp-vf init myproject --template k8s-cluster \
  --set cluster_name=homelab \
  --set worker_count=3
```

### 2. Configure Your VMs

```yaml
# config/vagrant.yaml
radp:
  env: dev
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

### 3. Run Vagrant Commands

Unlike standard Vagrant which requires `cd` to the Vagrantfile directory, radp-vf can run from anywhere:

```shell
# From project directory
cd myproject
radp-vf vg status
radp-vf vg up

# Or run from anywhere with -c flag
radp-vf -c ~/myproject/config vg status
radp-vf -c ~/myproject/config vg up

# Or set environment variable
export RADP_VAGRANT_CONFIG_DIR="$HOME/myproject/config"
radp-vf vg status
radp-vf vg ssh dev-my-cluster-node-1
radp-vf vg halt
radp-vf vg destroy
```

## Commands

| Command         | Description                             |
|-----------------|-----------------------------------------|
| `init [dir]`    | Initialize a project from template      |
| `vg <cmd>`      | Run vagrant commands                    |
| `list`          | List clusters and guests                |
| `info`          | Show environment information            |
| `validate`      | Validate YAML configuration             |
| `dump-config`   | Export merged configuration (JSON/YAML) |
| `generate`      | Generate standalone Vagrantfile         |
| `template list` | List available templates                |
| `template show` | Show template details                   |

### Global Options

| Option               | Description                                   |
|----------------------|-----------------------------------------------|
| `-c, --config <dir>` | Configuration directory (default: `./config`) |
| `-e, --env <name>`   | Override environment name                     |
| `-h, --help`         | Show help                                     |
| `-v, --version`      | Show version                                  |

### Environment Variables

| Variable                            | Description                                              |
|-------------------------------------|----------------------------------------------------------|
| `RADP_VF_HOME`                      | Framework installation directory                         |
| `RADP_VAGRANT_CONFIG_DIR`           | Configuration directory path                             |
| `RADP_VAGRANT_ENV`                  | Override environment name                                |
| `RADP_VAGRANT_CONFIG_BASE_FILENAME` | Override base config filename (supports any custom name) |

## Configuration Overview

### Multi-File Loading

Base configuration file is auto-detected (or set via `RADP_VAGRANT_CONFIG_BASE_FILENAME`):

1. `vagrant.yaml` or `config.yaml` - Base configuration (must contain `radp.env`)
2. `{base}-{env}.yaml` - Environment-specific clusters (e.g., `vagrant-dev.yaml` or `config-dev.yaml`)

### Inheritance Hierarchy

Settings inherit: **Global common → Cluster common → Guest**

| Config                   | Merge Behavior                                                               |
|--------------------------|------------------------------------------------------------------------------|
| box, provider, network   | Deep merge (guest overrides)                                                 |
| provisions               | Phase-aware: `global-pre → cluster-pre → guest → cluster-post → global-post` |
| triggers, synced-folders | Concatenate                                                                  |

### Builtin Provisions

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"
```

Available: `radp:crypto/gpg-import`, `radp:crypto/gpg-preset-passphrase`, `radp:git/clone`,
`radp:nfs/external-nfs-mount`, `radp:ssh/host-trust`, `radp:ssh/cluster-trust`, `radp:time/chrony-sync`,
`radp:yadm/clone`

### Builtin Triggers

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true
```

Available: `radp:system/disable-swap`, `radp:system/disable-selinux`, `radp:system/disable-firewalld`

## Documentation

- [Installation Guide](docs/installation.md) - Full installation options, upgrade, shell completion
- [Configuration Reference](docs/configuration-reference.md) - Box, provider, network, provisions, triggers, plugins
- [Advanced Topics](docs/advanced.md) - Convention defaults, validation, extending the framework

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and release process.

## License

[MIT](LICENSE)
