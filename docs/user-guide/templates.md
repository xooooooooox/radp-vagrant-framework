# Templates

Templates allow you to initialize projects from predefined configurations with variable substitution.

## Available Templates

| Template      | Description                                    |
|---------------|------------------------------------------------|
| `base`        | Minimal template for getting started (default) |
| `single-node` | Enhanced single VM with common provisions      |
| `k8s-cluster` | Multi-node Kubernetes cluster                  |

## Using Templates

```shell
# List available templates
radp-vf template list

# Show template details
radp-vf template show k8s-cluster

# Initialize with default template (base)
radp-vf init myproject

# Initialize with specific template
radp-vf init myproject --template k8s-cluster

# Initialize with variables
radp-vf init myproject --template k8s-cluster \
  --set cluster_name=homelab \
  --set worker_count=3
```

## Template Locations

- **Builtin templates**: `$RADP_VF_HOME/templates/`
- **User templates**: `~/.config/radp-vagrant/templates/`

User templates with the same name override builtin templates.

## Creating Custom Templates

### Template Structure

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
        │   └── scripts/
        └── triggers/
            ├── definitions/
            └── scripts/
```

### Template Metadata (template.yaml)

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
  - name: cpus
    desc: Number of CPUs
    default: 2
    type: integer
```

### Variable Properties

| Property   | Description                              |
|------------|------------------------------------------|
| `name`     | Variable identifier (used in `{{name}}`) |
| `desc`     | Human-readable description               |
| `default`  | Default value if not specified           |
| `required` | Must have a value                        |
| `type`     | `string` (default) or `integer`          |

### Variable Substitution

Use `{{variable}}` syntax in both file contents and filenames.

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

## Complete Example

### 1. Create the template directory

```bash
mkdir -p ~/.config/radp-vagrant/templates/my-dev-template/files/config
mkdir -p ~/.config/radp-vagrant/templates/my-dev-template/files/provisions/{definitions,scripts}
mkdir -p ~/.config/radp-vagrant/templates/my-dev-template/files/triggers/{definitions,scripts}
```

### 2. Create template.yaml

```yaml
name: my-dev-template
desc: Development environment with Docker
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

### 3. Create files/config/vagrant.yaml

```yaml
radp:
  env: {{env}}
  extend:
    vagrant:
      config:
        common:
          box:
            name: generic/ubuntu2204
          provider:
            mem: {{mem}}
            cpus: 2
```

### 4. Create files/config/vagrant-{{env}}.yaml

```yaml
radp:
  extend:
    vagrant:
      config:
        clusters:
          - name: {{cluster_name}}
            guests:
              - id: dev-1
```

### 5. Verify discovery

```bash
radp-vf template list
```

### 6. Use the template

```bash
radp-vf init myproject --template my-dev-template --set mem=8192
```

## Template Priority

When a user template has the same name as a builtin template, the user template takes precedence. This allows you to
override builtin templates with customized versions.

## See Also

- [Getting Started](../getting-started.md) - Initialize your first project
- [Configuration Reference](../configuration.md) - Configuration options
