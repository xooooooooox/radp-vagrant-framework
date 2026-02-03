# Triggers

Triggers execute scripts before or after Vagrant actions.

## Basic Syntax

Note: The `on` key must be quoted in YAML to prevent parsing as boolean.

```yaml
triggers:
  - name: before-up
    enabled: true
    "on": before
    type: action
    action:
      - up
      - reload
    run:
      inline: |
        echo "Starting..."
```

## YAML vs Vagrantfile Comparison

**YAML:**

```yaml
triggers:
  - name: notify-start
    enabled: true
    "on": after
    type: action
    action:
      - up
    run:
      inline: |
        echo "VM started at $(date)"
```

**Equivalent Vagrantfile:**

```ruby
config.trigger.after :up do |trigger|
  trigger.name = "notify-start"
  trigger.run = { inline: "echo 'VM started at $(date)'" }
end
```

## All Options

| Option     | Type         | Default  | Description                             |
|------------|--------------|----------|-----------------------------------------|
| `name`     | string       | -        | Trigger name                            |
| `enabled`  | boolean      | `true`   | Enable trigger                          |
| `"on"`     | string       | `before` | `before` or `after` (must be quoted!)   |
| `type`     | string       | `action` | `action`, `command`, `hook`             |
| `action`   | string/array | `[:up]`  | Actions to trigger on                   |
| `only-on`  | string/array | -        | Filter by machine name (supports regex) |
| `ignore`   | string/array | -        | Actions to ignore                       |
| `on-error` | string       | -        | `:halt` or `:continue`                  |
| `abort`    | boolean      | `false`  | Abort if trigger fails                  |

### Run Options (Host)

| Option   | Type         | Description           |
|----------|--------------|-----------------------|
| `inline` | string       | Inline script on host |
| `path`   | string       | Script path on host   |
| `args`   | string/array | Script arguments      |

### Run-Remote Options (Guest)

| Option       | Type         | Default | Description                     |
|--------------|--------------|---------|---------------------------------|
| `inline`     | string       | -       | Inline script on guest          |
| `path`       | string       | -       | Script path (uploaded to guest) |
| `args`       | string/array | -       | Script arguments                |
| `privileged` | boolean      | `false` | Run as root                     |

## Trigger Filtering with only-on

**YAML:**

```yaml
triggers:
  - name: master-setup
    "on": after
    action:
      - up
    only-on:
      - '/.*-master/'      # Regex pattern
      - dev-cluster-node-1 # Exact name
    run-remote:
      inline: echo "Running on master nodes"
      privileged: true
```

**Equivalent Vagrantfile:**

```ruby
config.trigger.after :up, only_on: [/.*-master/, "dev-cluster-node-1"] do |trigger|
  trigger.name = "master-setup"
  trigger.run_remote = {
    inline: "echo 'Running on master nodes'",
    privileged: true
  }
end
```

## Builtin Triggers

Builtin triggers use `radp:` prefix.

### Available Triggers

| Name                            | Description            | Default Timing  |
|---------------------------------|------------------------|-----------------|
| `radp:system/disable-swap`      | Disable swap (for K8s) | after up/reload |
| `radp:system/disable-selinux`   | Disable SELinux        | after up/reload |
| `radp:system/disable-firewalld` | Disable firewalld      | after up/reload |

### Usage

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true

  - name: radp:system/disable-selinux
    enabled: true
```

## User Triggers

Define reusable triggers with `user:` prefix.

### Directory Structure

```
myproject/
└── config/
    └── triggers/
        ├── definitions/
        │   ├── example.yaml          # -> user:example
        │   └── system/
        │       └── cleanup.yaml      # -> user:system/cleanup
        └── scripts/
            ├── example.sh
            └── system/
                └── cleanup.sh
```

### Definition Format (Host Execution)

```yaml
# config/triggers/definitions/notify.yaml
desc: Send notification after VM start
defaults:
  "on": after
  action:
    - up
  type: action
  run:
    inline: |
      echo "VM started at $(date)"
```

### Definition Format (Guest Execution)

```yaml
# config/triggers/definitions/guest-cleanup.yaml
desc: Cleanup inside guest VM
defaults:
  "on": after
  action:
    - up
  run-remote:
    script: guest-cleanup.sh
    privileged: true
```

### Definition with only-on Filter

```yaml
# config/triggers/definitions/worker-setup.yaml
desc: Setup worker nodes only
defaults:
  "on": after
  action:
    - up
  type: action
  only-on:
    - '/.*-worker-.*/'
  run-remote:
    inline: |
      echo "Configuring worker node..."
    privileged: true
```

### Usage

```yaml
triggers:
  - name: user:system/cleanup
    enabled: true
```

## Execution Location

| Option       | Execution    | Use Case                      |
|--------------|--------------|-------------------------------|
| `run`        | Host machine | Notifications, local scripts  |
| `run-remote` | Guest VM     | Guest configuration, services |

## See Also

- [Configuration Reference](../configuration.md) - Full configuration options
- [Provisions](./provisions.md) - VM provisioning
- [Extending](../developer/extending.md) - Add builtin triggers
