# Advanced Topics

## Convention-Based Defaults

The framework applies sensible defaults based on context:

| Field | Default Value | Example |
|-------|---------------|---------|
| `hostname` | `{guest-id}.{cluster}.{env}` | `node-1.my-cluster.dev` |
| `provider.name` | `{env}-{cluster}-{guest-id}` | `dev-my-cluster-node-1` |
| `provider.group-id` | `{env}/{cluster}` | `dev/my-cluster` |

## Validation Rules

The framework validates configurations and will raise errors for:

- **Duplicate cluster names**: No two clusters in the same environment file can have the same name
- **Duplicate guest IDs**: No two guests within the same cluster can have the same ID
- **Clusters in base config**: Clusters must be defined in `vagrant-{env}.yaml`, not in base `vagrant.yaml`

## Machine Naming

Vagrant machine names use `provider.name` (default: `{env}-{cluster}-{guest-id}`) to ensure uniqueness in `$VAGRANT_DOTFILE_PATH/machines/<name>`. This prevents conflicts when multiple clusters have guests with the same ID.

## Template System

Templates allow you to initialize projects from predefined configurations with variable substitution.

### Available Templates

| Template | Description |
|----------|-------------|
| `base` | Minimal template for getting started (default) |
| `single-node` | Enhanced single VM with common provisions pre-configured |
| `k8s-cluster` | Multi-node Kubernetes cluster with master and workers |

### Template Locations

- **Builtin templates**: `$RADP_VF_HOME/templates/`
- **User templates**: `~/.config/radp-vagrant/templates/`

User templates with the same name override builtin templates.

### Creating Custom Templates

1. Create a directory under `~/.config/radp-vagrant/templates/my-template/`

2. Create `template.yaml` with metadata:

```yaml
name: my-template
desc: My custom template
version: 1.0.0
variables:
  - name: env
    desc: Environment name
    default: dev
    required: true
  - name: cluster_name
    desc: Cluster name
    default: example
  - name: mem
    desc: Memory in MB
    default: 2048
    type: integer
```

3. Create `files/` directory with template files

4. Use `{{variable}}` placeholders in files and filenames

Example: `files/config/vagrant-{{env}}.yaml` becomes `vagrant-dev.yaml` when `env=dev`.

## Extending the Framework

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

### Add Builtin Provision

1. Create `lib/radp_vagrant/provisions/definitions/my-provision.yaml`:

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
  script: my-provision.sh
```

2. Create `lib/radp_vagrant/provisions/scripts/my-provision.sh`

3. Registry auto-discovers from YAML files (no code changes needed)

### Add Builtin Trigger

1. Create `lib/radp_vagrant/triggers/definitions/my-trigger.yaml`:

```yaml
desc: Human-readable description
defaults:
  "on": after
  action:
    - up
    - reload
  type: action
  on-error: continue
  run-remote:
    script: my-trigger.sh
```

2. Create `lib/radp_vagrant/triggers/scripts/my-trigger.sh`

3. Registry auto-discovers from YAML files (no code changes needed)

## Directory Structure

```
bin/
└── radp-vf                         # CLI entry point
completions/
├── radp-vf.bash                    # Bash completion
└── radp-vf.zsh                     # Zsh completion
install.sh                          # Installation script
templates/                          # Builtin project templates
├── base/
├── single-node/
└── k8s-cluster/
src/main/ruby/
├── Vagrantfile                     # Vagrant entry point
├── config/
│   ├── vagrant.yaml                # Base configuration
│   ├── vagrant-sample.yaml         # Sample environment
│   └── vagrant-local.yaml          # Local environment
└── lib/
    ├── radp_vagrant.rb             # Main coordinator
    └── radp_vagrant/
        ├── config_loader.rb        # Multi-file YAML loading
        ├── config_merger.rb        # Deep merge with array concatenation
        ├── generator.rb            # Vagrantfile generator (dry-run)
        ├── path_resolver.rb        # Unified two-level path resolution
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

## Debugging

### Dump Merged Configuration

```bash
# JSON format (default)
radp-vf dump-config

# YAML format
radp-vf dump-config -f yaml

# Filter by guest
radp-vf dump-config node-1

# Output to file
radp-vf dump-config -o config.json
```

### Generate Standalone Vagrantfile

```bash
# Preview to stdout
radp-vf generate

# Save to file
radp-vf generate Vagrantfile.preview
```

### Ruby API (for debugging)

```bash
cd src/main/ruby

# Dump merged configuration
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"

# Filter by guest_id or machine_name
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', 'guest-1')"

# Output as YAML
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', nil, format: :yaml)"

# Generate standalone Vagrantfile
ruby -r ./lib/radp_vagrant -e "puts RadpVagrant.generate_vagrantfile('config')"
```
