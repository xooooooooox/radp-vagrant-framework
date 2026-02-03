# Advanced Topics

## Convention-Based Defaults

The framework applies sensible defaults based on context:

| Field               | Default Value                | Example                 |
|---------------------|------------------------------|-------------------------|
| `hostname`          | `{guest-id}.{cluster}.{env}` | `node-1.my-cluster.dev` |
| `provider.name`     | `{env}-{cluster}-{guest-id}` | `dev-my-cluster-node-1` |
| `provider.group-id` | `{env}/{cluster}`            | `dev/my-cluster`        |

## Validation Rules

The framework validates configurations and will raise errors for:

- **Duplicate cluster names**: No two clusters in the same environment file can have the same name
- **Duplicate guest IDs**: No two guests within the same cluster can have the same ID
- **Clusters in base config**: Clusters must be defined in `vagrant-{env}.yaml`, not in base `vagrant.yaml`

## Machine Naming

Vagrant machine names use `provider.name` (default: `{env}-{cluster}-{guest-id}`) to ensure uniqueness in
`$VAGRANT_DOTFILE_PATH/machines/<name>`. This prevents conflicts when multiple clusters have guests with the same ID.

## Template System

Templates allow you to initialize projects from predefined configurations with variable substitution.

### Available Templates

| Template      | Description                                              |
|---------------|----------------------------------------------------------|
| `base`        | Minimal template for getting started (default)           |
| `single-node` | Enhanced single VM with common provisions pre-configured |
| `k8s-cluster` | Multi-node Kubernetes cluster with master and workers    |

### Template Locations

- **Builtin templates**: `$RADP_VF_HOME/templates/`
- **User templates**: `~/.config/radp-vagrant/templates/`

User templates with the same name override builtin templates.

### Creating Custom Templates

User templates allow you to create reusable project scaffolds with variable substitution.

#### Template Location

User templates are stored in `~/.config/radp-vagrant/templates/`. Each template is a directory containing:

```
~/.config/radp-vagrant/templates/
└── my-template/
    ├── template.yaml              # Required: metadata and variables
    └── files/                     # Required: files to copy
        ├── config/
        │   ├── vagrant.yaml
        │   └── vagrant-{{env}}.yaml
        ├── provisions/
        │   ├── definitions/
        │   │   └── setup.yaml
        │   └── scripts/
        │       └── setup.sh
        └── triggers/
            ├── definitions/
            │   └── example.yaml
            └── scripts/
                └── example.sh
```

#### Template Metadata (template.yaml)

```yaml
name: my-template
desc: My custom template for development environments
version: 1.0.0
variables:
  - name: env
    desc: Environment name (used for config file naming)
    default: dev
    required: true
  - name: cluster_name
    desc: Name of the cluster
    default: example
  - name: box_name
    desc: Vagrant box to use
    default: generic/ubuntu2204
  - name: mem
    desc: Memory allocation in MB
    default: 2048
    type: integer
  - name: cpus
    desc: Number of CPUs
    default: 2
    type: integer
```

**Variable types:**

- `string` (default): Text values
- `integer`: Numeric values (validated during init)

**Variable properties:**

- `name`: Variable identifier (used in `{{name}}` placeholders)
- `desc`: Human-readable description
- `default`: Default value if not specified via `--set`
- `required`: If true, must have a value (either default or user-provided)
- `type`: Variable type for validation

#### Variable Substitution

Use `{{variable}}` syntax in both file contents and filenames:

**In filenames:**

```
files/config/vagrant-{{env}}.yaml  →  vagrant-dev.yaml (when env=dev)
```

**In file contents:**

```yaml
# files/config/vagrant.yaml
radp:
  env: {{env}}
  extend:
    vagrant:
      config:
        common:
          box:
            name: {{box_name}}
          provider:
            mem: {{mem}}
            cpus: {{cpus}}
```

#### Complete Example

1. Create the template directory:

```bash
mkdir -p ~/.config/radp-vagrant/templates/my-dev-template/files/config
mkdir -p ~/.config/radp-vagrant/templates/my-dev-template/files/provisions/{definitions,scripts}
mkdir -p ~/.config/radp-vagrant/templates/my-dev-template/files/triggers/{definitions,scripts}
```

2. Create `template.yaml`:

```yaml
name: my-dev-template
desc: Development environment with Docker and common tools
version: 1.0.0
variables:
  - name: env
    desc: Environment name
    default: dev
    required: true
  - name: cluster_name
    desc: Cluster name
    default: devbox
  - name: mem
    desc: Memory in MB
    default: 4096
    type: integer
```

3. Create template files in `files/` directory

4. Verify discovery:

```bash
radp-vf template list
```

5. Use the template:

```bash
radp-vf init myproject --template my-dev-template --set mem=8192
```

#### Template Priority

When a user template has the same name as a builtin template, the user template takes precedence. This allows you to
override builtin templates with customized versions.

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

**Using external script file:**

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

**Using inline script:**

```yaml
desc: Simple inline provision
defaults:
  privileged: true
  run: once
  inline: |
    #!/bin/bash
    set -euo pipefail
    echo "Running inline provision..."
    echo "REQ_VAR: ${REQ_VAR}"
    echo "OPT_VAR: ${OPT_VAR:-default}"
  env:
    required:
      - name: REQ_VAR
        desc: Required variable
    optional:
      - name: OPT_VAR
        value: "default_value"
        desc: Optional variable
```

2. If using `script`, create `lib/radp_vagrant/provisions/scripts/my-provision.sh`

3. Registry auto-discovers from YAML files (no code changes needed)

**Note:** Use `script` for complex logic or when you need syntax highlighting/linting. Use `inline` for simple,
self-contained scripts.

### Add Builtin Trigger

1. Create `lib/radp_vagrant/triggers/definitions/my-trigger.yaml`:

**Using external script file (run on guest):**

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

**Using inline script (run on guest):**

```yaml
desc: Inline trigger that runs on guest
defaults:
  "on": after
  action:
    - up
    - reload
  type: action
  on-error: continue
  run-remote:
    inline: |
      #!/bin/bash
      set -euo pipefail
      echo "Running on guest after VM start..."
      # Add your commands here
    privileged: true    # Run as root (default: false)
```

**Using inline script (run on host):**

```yaml
desc: Inline trigger that runs on host
defaults:
  "on": after
  action:
    - up
  type: action
  run:
    inline: |
      echo "VM started at $(date)"
      # Notification or host-side operations
```

**Using only-on to filter guests:**

```yaml
desc: Trigger only for specific guests
defaults:
  "on": after
  action:
    - up
  type: action
  only-on:
    - '/.*-master/'       # Regex: match all master nodes
    - dev-cluster-node-1  # Exact machine name
  run-remote:
    inline: |
      echo "Running only on master nodes..."
    privileged: true
```

2. If using `script`, create `lib/radp_vagrant/triggers/scripts/my-trigger.sh`

3. Registry auto-discovers from YAML files (no code changes needed)

**Trigger execution location:**

| Option       | Execution Location | Use Case                                      |
|--------------|--------------------|-----------------------------------------------|
| `run`        | Host machine       | Notifications, local scripts, host-side setup |
| `run-remote` | Guest VM           | Guest configuration, service management       |

**Notes:**

- Both `run` and `run-remote` support either `script` (external file) or `inline` (embedded script)
- `run-remote` supports `privileged` option (default: `false`) to run as root
- `only-on` filters by machine name (not guest ID), supports regex patterns `/pattern/`

## Directory Structure

```
bin/
└── radp-vf                         # Thin CLI entry point
completions/
├── radp-vf.bash                    # Bash completion
└── radp-vf.zsh                     # Zsh completion
install.sh                          # Installation script
templates/                          # Builtin project templates
├── base/
├── single-node/
└── k8s-cluster/
src/main/shell/                     # Bash CLI layer
├── commands/                       # Command auto-discovery
│   ├── completion.sh               # radp-vf completion <shell>
│   ├── dump-config.sh              # radp-vf dump-config
│   ├── generate.sh                 # radp-vf generate
│   ├── info.sh                     # radp-vf info
│   ├── init.sh                     # radp-vf init
│   ├── list.sh                     # radp-vf list
│   ├── validate.sh                 # radp-vf validate
│   ├── version.sh                  # radp-vf version
│   ├── vg.sh                       # radp-vf vg (passthrough to vagrant)
│   └── template/                   # Subcommands
│       ├── list.sh                 # radp-vf template list
│       └── show.sh                 # radp-vf template show
├── config/
│   ├── config.yaml                 # Framework configuration
│   └── _ide.sh                     # IDE code completion support
└── libs/
    └── vf/                         # Auto-loaded library functions
        ├── _common.sh              # Path resolution, config detection
        └── ruby_bridge.sh          # Ruby CLI call wrappers
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

## Targeting VMs by Cluster

Instead of typing full machine names like `homelab-gitlab-runner-1`, you can target VMs by cluster name using the
`--cluster` (`-C`) and `--guest-ids` (`-G`) options.

### Basic Usage

```bash
# Start all VMs in a cluster
radp-vf vg up --cluster=gitlab-runner
radp-vf vg up -C gitlab-runner

# Start specific guests in a cluster (comma-separated)
radp-vf vg up --cluster=gitlab-runner --guest-ids=1,2
radp-vf vg up -C gitlab-runner -G 1,2

# Multiple clusters (comma-separated)
radp-vf vg up --cluster=gitlab-runner,develop-centos9
radp-vf vg up -C gitlab-runner,develop-centos9

# Original machine name syntax still works
radp-vf vg up homelab-gitlab-runner-1
```

### Shell Completion

Completion is supported for all targeting options:

```bash
# Complete cluster names
radp-vf vg up --cluster= <TAB>
radp-vf vg up -C <TAB>

# Complete guest IDs for a cluster
radp-vf vg up -C gitlab-runner --guest-ids=<TAB>
radp-vf vg up -C gitlab-runner -G <TAB>

# Complete machine names (positional arguments)
radp-vf vg up <TAB>
```

### How It Works

1. The `--cluster` option accepts cluster names (as defined in your YAML config)
2. The `--guest-ids` option filters guests within the specified cluster(s)
3. The framework resolves these to full machine names (e.g., `homelab-gitlab-runner-1`)
4. The resolved names are passed to Vagrant

### Options Reference

| Option              | Short | Description                                       |
|---------------------|-------|---------------------------------------------------|
| `--cluster <names>` | `-C`  | Cluster names (comma-separated for multiple)      |
| `--guest-ids <ids>` | `-G`  | Guest IDs (comma-separated, requires `--cluster`) |

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
