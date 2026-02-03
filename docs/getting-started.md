# Getting Started

This guide helps you create your first Vagrant project with radp-vagrant-framework.

## Prerequisites

- Ruby 2.7+
- Vagrant 2.0+
- VirtualBox (or other supported provider)
- [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework)

## Installation

### Homebrew (macOS)

```shell
brew tap xooooooooox/radp
brew install radp-vagrant-framework
```

### Script Install

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh
  | bash
```

See [Installation Guide](./installation.md) for more options.

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

**Base config (`config/vagrant.yaml`):**

```yaml
radp:
  env: dev
  extend:
    vagrant:
      config:
        common:
          box:
            name: generic/ubuntu2204
```

**Environment config (`config/vagrant-dev.yaml`):**

```yaml
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

```shell
# From project directory
cd myproject
radp-vf vg status
radp-vf vg up

# Or from anywhere with -c option
radp-vf vg -c ~/myproject/config status
radp-vf vg -c ~/myproject/config up
```

### 4. Target VMs by Cluster

```shell
# Start all VMs in a cluster
radp-vf vg up -C my-cluster

# Start specific guests
radp-vf vg up -C my-cluster -G 1,2

# Multiple clusters
radp-vf vg up -C cluster1,cluster2
```

## Project Structure

```
myproject/
├── config/
│   ├── vagrant.yaml           # Base configuration
│   └── vagrant-dev.yaml       # Environment-specific clusters
├── provisions/                 # User provisions (optional)
│   ├── definitions/
│   └── scripts/
└── triggers/                   # User triggers (optional)
    ├── definitions/
    └── scripts/
```

## YAML vs Vagrantfile Comparison

**YAML:**

```yaml
guests:
  - id: node-1
    network:
      private-network:
        ip: 192.168.56.10
```

**Equivalent Vagrantfile:**

```ruby
config.vm.define "node-1" do |node|
  node.vm.network "private_network", ip: "192.168.56.10"
end
```

## Next Steps

- [Configuration Reference](./configuration.md) - All configuration options
- [Provisions](./user-guide/provisions.md) - Add provisioning scripts
- [Triggers](./user-guide/triggers.md) - Add before/after triggers
- [Templates](./user-guide/templates.md) - Use and create templates
