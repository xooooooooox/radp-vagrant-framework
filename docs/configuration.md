# Configuration Reference

This document covers the core configuration options for radp-vagrant-framework.

## Quick Example

```yaml
# config/vagrant.yaml - Base configuration
radp:
  env: dev
  extend:
    vagrant:
      plugins:
        - name: vagrant-hostmanager
          required: true
          options:
            enabled: true
            manage_host: true
      config:
        common:
          box:
            name: generic/ubuntu2204
          provider:
            mem: 2048
            cpus: 2
```

```yaml
# config/vagrant-dev.yaml - Environment-specific
radp:
  extend:
    vagrant:
      config:
        clusters:
          - name: my-cluster
            guests:
              - id: node-1
                network:
                  private-network:
                    enabled: true
                    ip: 172.16.10.10
```

## Multi-File Loading

Configuration is loaded in order with deep merging:

1. **Base config** (must contain `radp.env`)
    - Auto-detected: `vagrant.yaml` (preferred) or `config.yaml`
    - Or set via `RADP_VAGRANT_CONFIG_BASE_FILENAME`
2. **Environment config**: `{base}-{env}.yaml` (e.g., `vagrant-dev.yaml`)

## Configuration Inheritance

### File-Level Merging

| Type    | Merge Behavior      |
|---------|---------------------|
| Scalars | Override (env wins) |
| Hashes  | Deep merge          |
| Arrays  | Concatenate         |
| Plugins | Merge by name       |

### Guest-Level Inheritance

Settings inherit: **global common → cluster common → guest**

| Config                   | Merge Behavior                                                               |
|--------------------------|------------------------------------------------------------------------------|
| box, provider, network   | Deep merge (guest overrides)                                                 |
| provisions               | Phase-aware: `global-pre → cluster-pre → guest → cluster-post → global-post` |
| triggers, synced-folders | Concatenate                                                                  |

## Box

```yaml
box:
  name: generic/centos9s
  version: 4.3.12
  check-update: false
```

## Provider

```yaml
provider:
  type: virtualbox
  name: my-vm                     # default: {env}-{cluster}-{guest-id}
  group-id: my-group              # default: {env}/{cluster}
  mem: 2048
  cpus: 2
  gui: false
  customize:
    - [ 'modifyvm', ':id', '--nictype1', 'virtio' ]
```

| Option      | Type    | Default                      | Description                   |
|-------------|---------|------------------------------|-------------------------------|
| `type`      | string  | `virtualbox`                 | Provider type                 |
| `name`      | string  | `{env}-{cluster}-{guest-id}` | VM name                       |
| `group-id`  | string  | `{env}/{cluster}`            | VirtualBox group              |
| `mem`       | number  | `2048`                       | Memory in MB                  |
| `cpus`      | number  | `2`                          | Number of CPUs                |
| `gui`       | boolean | `false`                      | Show VirtualBox GUI           |
| `customize` | array   | -                            | VirtualBox customize commands |

## Disk Size

Resize the primary disk (requires `vagrant-disksize` plugin):

```yaml
guests:
  - id: master
    disk_size: 50GB
    box:
      name: ubuntu/jammy64
```

## Network

```yaml
hostname: node.local              # default: {guest-id}.{cluster}.{env}

network:
  private-network:
    enabled: true
    type: static                  # dhcp or static
    ip: 172.16.10.100
    netmask: 255.255.255.0
  public-network:
    enabled: true
    type: static
    ip:
      - 192.168.10.100
      - 192.168.10.101
    bridge:
      - "en0: Wi-Fi"
  forwarded-ports:
    - enabled: true
      guest: 80
      host: 8080
      protocol: tcp
```

### Private Network Options

| Option        | Type         | Default  | Description              |
|---------------|--------------|----------|--------------------------|
| `enabled`     | boolean      | -        | Enable private network   |
| `type`        | string       | `static` | `dhcp` or `static`       |
| `ip`          | string/array | -        | Static IP address(es)    |
| `netmask`     | string       | -        | Subnet mask              |
| `auto-config` | boolean      | `true`   | Auto-configure interface |

### Public Network Options

| Option    | Type         | Default  | Description           |
|-----------|--------------|----------|-----------------------|
| `enabled` | boolean      | -        | Enable public network |
| `type`    | string       | `static` | `dhcp` or `static`    |
| `ip`      | string/array | -        | Static IP address(es) |
| `bridge`  | string/array | -        | Bridge interface(s)   |

### Forwarded Ports Options

| Option         | Type    | Default | Description                 |
|----------------|---------|---------|-----------------------------|
| `enabled`      | boolean | -       | Enable port forwarding      |
| `guest`        | number  | -       | Guest port (required)       |
| `host`         | number  | -       | Host port (required)        |
| `protocol`     | string  | `tcp`   | `tcp` or `udp`              |
| `auto-correct` | boolean | `false` | Auto-correct port collision |

## Synced Folders

```yaml
synced-folders:
  basic:
    - enabled: true
      host: ./data
      guest: /data
      create: true
      owner: vagrant
      group: vagrant
  nfs:
    - enabled: true
      host: ./nfs-data
      guest: /nfs-data
      nfs-version: 4
      bindfs:
        enabled: true
        force_user: www-data
        force_group: www-data
```

## Provisions

Basic syntax:

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

### Builtin Provisions

Use `radp:` prefix for builtin provisions:

```yaml
provisions:
  - name: radp:time/chrony-sync
    enabled: true
    env:
      NTP_SERVERS: "ntp.aliyun.com"
      TIMEZONE: "Asia/Shanghai"
```

Available: `radp:crypto/gpg-import`, `radp:crypto/gpg-preset-passphrase`, `radp:git/clone`,
`radp:nfs/external-nfs-mount`, `radp:ssh/host-trust`, `radp:ssh/cluster-trust`, `radp:system/expand-lvm`,
`radp:time/chrony-sync`, `radp:yadm/clone`

See [Builtin Provisions Reference](reference/builtin-provisions.md) for details.

### User Provisions

Define reusable provisions with `user:` prefix:

```yaml
provisions:
  - name: user:docker/setup
    enabled: true
    env:
      DOCKER_VERSION: "24.0"
```

See [Provisions Guide](user-guide/provisions.md) for details.

## Triggers

Basic syntax:

```yaml
triggers:
  - name: before-up
    enabled: true
    "on": before                  # Must be quoted!
    type: action
    action:
      - up
      - reload
    run:
      inline: echo "Starting..."
```

| Option       | Type         | Default  | Description                              |
|--------------|--------------|----------|------------------------------------------|
| `name`       | string       | -        | Trigger name                             |
| `enabled`    | boolean      | `true`   | Enable this trigger                      |
| `"on"`       | string       | `before` | `before` or `after` (must be quoted!)    |
| `type`       | string       | `action` | `action`, `command`, or `hook`           |
| `action`     | string/array | `[:up]`  | Actions to trigger on                    |
| `only-on`    | string/array | -        | Filter by machine name (supports regex)  |
| `run`        | hash         | -        | Local execution (inline/path/args)       |
| `run-remote` | hash         | -        | Guest execution (inline/path/privileged) |

### Builtin Triggers

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true
```

Available: `radp:system/disable-swap`, `radp:system/disable-selinux`, `radp:system/disable-firewalld`

See [Builtin Triggers Reference](reference/builtin-triggers.md) for details.

### User Triggers

Define reusable triggers with `user:` prefix:

```yaml
triggers:
  - name: user:system/cleanup
    enabled: true
```

See [Triggers Guide](user-guide/triggers.md) for details.

## Plugins

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      enabled: true
      manage_host: true
      manage_guest: true
```

Supported plugins:

- `vagrant-hostmanager` - Host file management
- `vagrant-vbguest` - VirtualBox Guest Additions
- `vagrant-proxyconf` - Proxy configuration
- `vagrant-bindfs` - Bind mounts (per synced-folder)
- `vagrant-disksize` - Disk resizing (VirtualBox only)

See [Plugins Guide](user-guide/plugins.md) for details.

## See Also

- [Getting Started](getting-started.md) - Quick start guide
- [Provisions Guide](user-guide/provisions.md) - Detailed provisions documentation
- [Triggers Guide](user-guide/triggers.md) - Detailed triggers documentation
- [Plugins Guide](user-guide/plugins.md) - Detailed plugins documentation
- [CLI Reference](reference/cli-reference.md) - Command reference
