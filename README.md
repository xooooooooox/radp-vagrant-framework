# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

[![GitHub Release](https://img.shields.io/github/v/release/xooooooooox/radp-vagrant-framework?label=Release)](https://github.com/xooooooooox/radp-vagrant-framework/releases)
[![Copr build status](https://copr.fedorainfracloud.org/coprs/xooooooooox/radp/package/radp-vagrant-framework/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/xooooooooox/radp/package/radp-vagrant-framework/)
[![OBS package build status](https://build.opensuse.org/projects/home:xooooooooox:radp/packages/radp-vagrant-framework/badge.svg)](https://build.opensuse.org/package/show/home:xooooooooox:radp/radp-vagrant-framework)

[![CI: Check](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/ci.yml?label=CI)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/ci.yml)
[![CI: COPR](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/build-copr-package.yml?label=CI%3A%20COPR)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/build-copr-package.yml)
[![CI: OBS](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/build-obs-package.yml?label=CI%3A%20OBS)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/build-obs-package.yml)
[![CI: Homebrew](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/update-homebrew-tap.yml?label=Homebrew%20tap)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/update-homebrew-tap.yml)

[![COPR packages](https://img.shields.io/badge/COPR-packages-4b8bbe)](https://download.copr.fedorainfracloud.org/results/xooooooooox/radp/)
[![OBS packages](https://img.shields.io/badge/OBS-packages-4b8bbe)](https://software.opensuse.org//download.html?project=home%3Axooooooooox%3Aradp&package=radp-vagrant-framework)

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
- [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework) (required, installed automatically via
  Homebrew/package managers)

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

### Portable Binary

Download a self-contained portable binary
from [GitHub Releases](https://github.com/xooooooooox/radp-vagrant-framework/releases):

```shell
# macOS Apple Silicon
curl -fsSL https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-darwin-arm64 -o radp-vf
chmod +x radp-vf
./radp-vf --help

# Linux x86_64
curl -fsSL https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-linux-amd64 -o radp-vf
chmod +x radp-vf
./radp-vf --help
```

> **Note**: Portable binary requires [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework) to be
> installed.

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

# Or run from anywhere with -c option
radp-vf vg -c ~/myproject/config status
radp-vf vg -c ~/myproject/config up

# Or set environment variable
export RADP_VAGRANT_CONFIG_DIR="$HOME/myproject/config"
radp-vf vg status
radp-vf vg ssh dev-my-cluster-node-1
radp-vf vg halt
radp-vf vg destroy
```

### 4. Target VMs by Cluster

Instead of typing full machine names, use `--cluster` (`-C`) to target VMs by cluster:

```shell
# Start all VMs in a cluster
radp-vf vg up -C gitlab-runner

# Start specific guests in a cluster
radp-vf vg up -C gitlab-runner -G 1,2

# Multiple clusters
radp-vf vg up -C gitlab-runner,develop-centos9

# Original syntax still works
radp-vf vg up homelab-gitlab-runner-1
```

Shell completion is supported for cluster names, guest IDs, and machine names:

```bash
# Complete cluster names
radp-vf vg -c /path/to/config --cluster <tab>

# Complete guest IDs (requires --cluster)
radp-vf vg -c /path/to/config --cluster develop --guest-ids <tab>

# Complete machine names (positional args)
radp-vf vg -c /path/to/config status <tab>
```

Config resolution for completion (in order):

1. `-c` / `--config` from command line
2. `RADP_VAGRANT_CONFIG_DIR` environment variable
3. `./config` directory (if exists)

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

### Option Placement

```
radp-vf [framework-options] <command> [command-options] [arguments]
```

**Framework options** (before command):

| Option       | Description            |
|--------------|------------------------|
| `-v`         | Enable verbose logging |
| `--debug`    | Enable debug logging   |
| `-h, --help` | Show help              |
| `--version`  | Show version           |

**Command options** (after command, before arguments):

| Option               | Description                                   |
|----------------------|-----------------------------------------------|
| `-c, --config <dir>` | Configuration directory (default: `./config`) |
| `-e, --env <name>`   | Override environment name                     |
| `-h, --help`         | Show help for command                         |

**`vg` command specific options:**

| Option                  | Description                                       |
|-------------------------|---------------------------------------------------|
| `-C, --cluster <names>` | Cluster names (comma-separated for multiple)      |
| `-G, --guest-ids <ids>` | Guest IDs (comma-separated, requires `--cluster`) |

**Examples:**

```shell
# Framework option before command
radp-vf -v list

# Command options after command name
radp-vf list -c ./config -e prod
radp-vf vg -c ./config status
radp-vf dump-config -f yaml -o config.yaml

# Target VMs by cluster (vg command)
radp-vf vg status -C my-cluster
radp-vf vg up -C gitlab-runner -G 1,2
radp-vf vg halt -C cluster1,cluster2
```

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

### User-Defined Provisions & Triggers

Define reusable components with `user:` prefix in your project:

```
myproject/
└── config/
    ├── provisions/
    │   ├── definitions/
    │   │   └── docker/setup.yaml    # -> user:docker/setup
    │   └── scripts/
    │       └── docker/setup.sh
    └── triggers/
        ├── definitions/
        │   └── system/cleanup.yaml  # -> user:system/cleanup
        └── scripts/
            └── system/cleanup.sh
```

Usage:

```yaml
provisions:
  - name: user:docker/setup
    enabled: true

triggers:
  - name: user:system/cleanup
    enabled: true
```

### User Templates

Create custom templates in `~/.config/radp-vagrant/templates/`:

```
~/.config/radp-vagrant/templates/
└── my-template/
    ├── template.yaml              # Metadata and variables
    └── files/                     # Files to copy
        ├── config/
        │   ├── vagrant.yaml
        │   └── vagrant-{{env}}.yaml
        ├── provisions/
        └── triggers/
```

See [Templates Guide](docs/user-guide/templates.md) for detailed template creation guide.

## Documentation

- [Getting Started](docs/getting-started.md) - Quick start guide
- [Installation Guide](docs/installation.md) - Full installation options, upgrade, shell completion
- [Configuration Reference](docs/configuration.md) - Box, provider, network, provisions, triggers, plugins
- [User Guide](docs/user-guide/) - Provisions, triggers, plugins, templates
- [Developer Guide](docs/developer/) - Architecture, extending the framework
- [CLI Reference](docs/reference/cli-reference.md) - Complete CLI command reference

## Related Projects

- [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework) - Bash engineering & CLI framework (
  dependency)
- [homelabctl](https://github.com/xooooooooox/homelabctl) - Homelab infrastructure CLI (uses this framework)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and release process.

## License

[MIT](LICENSE)
