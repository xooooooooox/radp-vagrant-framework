# Provisions

Provisions configure and customize VMs after they are created.

## Basic Syntax

```yaml
provisions:
  - name: setup
    enabled: true
    type: shell
    privileged: true
    run: once
    inline: |
      echo "Hello $MY_VAR"
    env:
      MY_VAR: "world"
```

## YAML vs Vagrantfile Comparison

**YAML:**

```yaml
provisions:
  - name: install-nginx
    enabled: true
    type: shell
    privileged: true
    run: once
    inline: |
      apt-get update -qq
      apt-get install -y nginx
```

**Equivalent Vagrantfile:**

```ruby
config.vm.provision "install-nginx", type: "shell", run: "once", privileged: true do |s|
  s.inline = <<-SHELL
    apt-get update -qq
    apt-get install -y nginx
  SHELL
end
```

## All Options

| Option       | Type         | Default | Description                   |
|--------------|--------------|---------|-------------------------------|
| `name`       | string       | -       | Provision name                |
| `enabled`    | boolean      | `true`  | Enable this provision         |
| `type`       | string       | `shell` | `shell` or `file`             |
| `privileged` | boolean      | `false` | Run as root                   |
| `run`        | string       | `once`  | `once`, `always`, `never`     |
| `phase`      | string       | `pre`   | `pre` or `post` (common only) |
| `inline`     | string       | -       | Inline script content         |
| `path`       | string       | -       | External script path          |
| `args`       | string/array | -       | Script arguments              |
| `env`        | hash         | -       | Environment variables         |
| `reboot`     | boolean      | `false` | Reboot after execution        |
| `sensitive`  | boolean      | `false` | Hide output                   |

## Phase Field (Common Provisions)

The `phase` field controls when common provisions run:

- `pre` (default): Runs before guest provisions
- `post`: Runs after guest provisions

Execution order: `global-pre → cluster-pre → guest → cluster-post → global-post`

**YAML:**

```yaml
# Global common provisions with phase
common:
  provisions:
    - name: global-init
      phase: pre
      inline: echo "Runs first"

    - name: global-cleanup
      phase: post
      inline: echo "Runs last"
```

**Equivalent Vagrantfile:**

```ruby
# Global pre-provision
config.vm.provision "global-init", type: "shell" do |s|
  s.inline = "echo 'Runs first'"
end

# ... guest provisions ...

# Global post-provision
config.vm.provision "global-cleanup", type: "shell" do |s|
  s.inline = "echo 'Runs last'"
end
```

## Builtin Provisions

Builtin provisions use `radp:` prefix with sensible defaults.

### Available Provisions

| Name                                | Description               |
|-------------------------------------|---------------------------|
| `radp:crypto/gpg-import`            | Import GPG keys           |
| `radp:crypto/gpg-preset-passphrase` | Preset GPG passphrase     |
| `radp:git/clone`                    | Clone git repository      |
| `radp:nfs/external-nfs-mount`       | Mount external NFS shares |
| `radp:ssh/host-trust`               | Add host SSH key to guest |
| `radp:ssh/cluster-trust`            | SSH trust between VMs     |
| `radp:system/expand-lvm`            | Expand LVM partition      |
| `radp:time/chrony-sync`             | Configure time sync       |
| `radp:yadm/clone`                   | Clone dotfiles with yadm  |

### Usage Example

**YAML:**

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"

  - name: radp:time/chrony-sync
    enabled: true
    env:
      NTP_SERVERS: "ntp.aliyun.com"
      TIMEZONE: "Asia/Shanghai"
```

See [Builtin Provisions Reference](../reference/builtin-provisions.md) for all options.

## User Provisions

Define reusable provisions with `user:` prefix in your project.

### Directory Structure

```
myproject/
└── config/
    └── provisions/
        ├── definitions/
        │   ├── example.yaml          # -> user:example
        │   └── docker/
        │       └── setup.yaml        # -> user:docker/setup
        └── scripts/
            ├── example.sh
            └── docker/
                └── setup.sh
```

### Definition Format (Script)

```yaml
# config/provisions/definitions/docker/setup.yaml
desc: Install and configure Docker
defaults:
  privileged: true
  run: once
  env:
    required:
      - name: DOCKER_VERSION
        desc: Docker version to install
    optional:
      - name: DOCKER_COMPOSE
        value: "true"
        desc: Install Docker Compose
  script: setup.sh
```

### Definition Format (Inline)

```yaml
# config/provisions/definitions/hello.yaml
desc: Simple hello world provision
defaults:
  privileged: false
  run: once
  inline: |
    echo "Hello from inline provision!"
    echo "Environment: ${MY_VAR:-default}"
  env:
    optional:
      - name: MY_VAR
        value: "world"
```

### Usage

```yaml
provisions:
  - name: user:docker/setup
    enabled: true
    env:
      DOCKER_VERSION: "24.0"
```

## Script Path Resolution

| Provision Type    | Script Location                        | Resolution       |
|-------------------|----------------------------------------|------------------|
| Builtin (`radp:`) | `lib/radp_vagrant/provisions/scripts/` | Absolute path    |
| User (`user:`)    | `{config_dir}/provisions/scripts/`     | Two-level lookup |

For user provisions, config_dir takes precedence over project_root.

## See Also

- [Configuration Reference](../configuration.md) - Full configuration options
- [Builtin Provisions Reference](../reference/builtin-provisions.md) - All builtin provisions
- [Triggers](./triggers.md) - Before/after triggers
