# Configuration Reference

## Complete Configuration Example

Below is a complete example showing all major configuration options. This example uses two files: `vagrant.yaml` (base)
and `vagrant-dev.yaml` (environment-specific).

```yaml
# config/vagrant.yaml - Base Configuration (Complete Example)
radp:
  # Environment name - determines which vagrant-{env}.yaml to load
  env: dev

  extend:
    vagrant:
      # Plugin configuration (global)
      plugins:
        - name: vagrant-hostmanager
          required: true
          options:
            enabled: true
            manage_host: true
            manage_guest: true
            include_offline: false

        - name: vagrant-vbguest
          required: true
          options:
            auto_update: true
            auto_reboot: true

      # VM configuration
      config:
        # Global common settings (inherited by all clusters and guests)
        common:
          # Default box for all VMs
          box:
            name: generic/ubuntu2204
            check-update: false

          # Default provider settings
          provider:
            type: virtualbox
            mem: 2048
            cpus: 2
            gui: false

          # Global provisions (phase: pre runs before guest provisions)
          provisions:
            - name: global-init
              enabled: true
              type: shell
              phase: pre
              privileged: true
              run: once
              inline: |
                echo "Global initialization..."
                apt-get update -qq

            - name: global-cleanup
              enabled: true
              type: shell
              phase: post
              run: once
              inline: echo "Global cleanup..."

          # Global synced folders
          synced-folders:
            basic:
              - enabled: true
                host: ./shared
                guest: /shared
                create: true
                owner: vagrant
                group: vagrant

          # Global triggers
          triggers:
            - name: radp:system/disable-swap
              enabled: true
```

```yaml
# config/vagrant-dev.yaml - Environment Configuration (Complete Example)
radp:
  extend:
    vagrant:
      # Plugin options can be extended/overridden per environment
      plugins:
        - name: vagrant-hostmanager
          options:
            provisioner: enabled
            ip_resolver:
              enabled: true
              execute: "hostname -I | awk '{print $2}'"
              regex: "^(\\S+)"

      config:
        # Cluster definitions (must be in environment file, not base)
        clusters:
          - name: web-cluster
            # Cluster-level common settings
            common:
              box:
                name: generic/centos9s

              provider:
                mem: 4096
                cpus: 4

              provisions:
                - name: cluster-init
                  enabled: true
                  type: shell
                  phase: pre
                  inline: echo "Web cluster initialization..."

            # Guest definitions
            guests:
              - id: web-1
                # Hostname (default: {id}.{cluster}.{env})
                hostname: web-1.web-cluster.dev

                # Per-guest hostmanager settings
                hostmanager:
                  aliases:
                    - web1.local
                    - web1

                # Provider overrides
                provider:
                  name: dev-web-cluster-web-1
                  group-id: dev/web-cluster
                  mem: 8192
                  cpus: 8
                  customize:
                    - [ 'modifyvm', ':id', '--nictype1', 'virtio' ]

                # Network configuration
                network:
                  private-network:
                    enabled: true
                    type: static
                    ip: 172.16.10.10
                    netmask: 255.255.255.0
                  forwarded-ports:
                    - enabled: true
                      guest: 80
                      host: 8080
                      protocol: tcp
                    - enabled: true
                      guest: 443
                      host: 8443

                # Guest-specific synced folders
                synced-folders:
                  nfs:
                    - enabled: true
                      host: ./app
                      guest: /var/www/app
                      bindfs:
                        enabled: true
                        force_user: www-data
                        force_group: www-data

                # Guest-specific provisions
                provisions:
                  - name: install-nginx
                    enabled: true
                    type: shell
                    privileged: true
                    run: once
                    inline: |
                      apt-get install -y nginx
                      systemctl enable nginx

                  - name: radp:ssh/host-trust
                    enabled: true
                    env:
                      HOST_SSH_PUBLIC_KEY_FILE: "/vagrant/keys/host_key.pub"

              - id: web-2
                network:
                  private-network:
                    enabled: true
                    type: static
                    ip: 172.16.10.11

          - name: db-cluster
            common:
              box:
                name: generic/rocky9
              provider:
                mem: 4096

            guests:
              - id: db-1
                network:
                  private-network:
                    enabled: true
                    type: static
                    ip: 172.16.10.20

                provisions:
                  - name: radp:time/chrony-sync
                    enabled: true
                    env:
                      NTP_SERVERS: "ntp.aliyun.com"
                      TIMEZONE: "Asia/Shanghai"

                triggers:
                  - name: radp:system/disable-firewalld
                    enabled: true
```

## Configuration Structure

### Multi-File Loading

Configuration is loaded in order with deep merging:

1. `vagrant.yaml` - Base configuration (must contain `radp.env`)
2. `vagrant-{env}.yaml` - Environment-specific clusters

```yaml
# vagrant.yaml - Base configuration
radp:
  env: dev  # Determines which env file to load
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
          # Global settings inherited by all guests
          provisions:
            - name: global-init
              enabled: true
              type: shell
              run: once
              inline: echo "Hello"

# vagrant-dev.yaml - Dev environment
radp:
  extend:
    vagrant:
      config:
        clusters:
          - name: my-cluster
            guests:
              - id: node-1
                box:
                  name: generic/centos9s
```

### Configuration Inheritance

#### File-Level Merging

`vagrant.yaml` (base) + `vagrant-{env}.yaml` (environment) are deep merged:

| Type        | Merge Behavior                                 |
|-------------|------------------------------------------------|
| Scalars     | Override (env wins)                            |
| Hashes      | Deep merge                                     |
| Arrays      | Concatenate                                    |
| **Plugins** | **Merge by name** (env extends/overrides base) |

**Plugin merge example:**

```yaml
# vagrant.yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      manage_host: true
      manage_guest: true

# vagrant-dev.yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      ip_resolver:
        enabled: true
        execute: "hostname -I | awk '{print $2}'"
        regex: "^(\\S+)"

# Result (merged by name)
plugins:
  - name: vagrant-hostmanager
    required: true                # inherited from base
    options:
      manage_host: true           # inherited from base
      manage_guest: true          # inherited from base
      provisioner: enabled        # added from env
      ip_resolver: { ... }        # added from env
```

#### Guest-Level Inheritance

Within a config file, guest settings inherit from: **global common → cluster common → guest**

| Config                           | Merge Behavior                                                                      |
|----------------------------------|-------------------------------------------------------------------------------------|
| box, provider, network, hostname | Deep merge (guest overrides)                                                        |
| hostmanager                      | Deep merge (guest overrides)                                                        |
| provisions                       | Phase-aware concat: `global-pre → cluster-pre → guest → cluster-post → global-post` |
| triggers                         | Concatenate                                                                         |
| synced-folders                   | Concatenate                                                                         |

## Box

```yaml
box:
  name: generic/centos9s          # Box name
  version: 4.3.12                 # Box version
  check-update: false             # Disable update check
```

## Provider

```yaml
provider:
  type: virtualbox                # Provider type
  name: my-vm                     # VM name (default: {env}-{cluster}-{guest-id})
  group-id: my-group              # VirtualBox group (default: {env}/{cluster})
  mem: 2048                       # Memory in MB
  cpus: 2                         # CPU count
  gui: false                      # Show GUI
  customize: # VirtualBox-specific customizations
    - [ 'modifyvm', ':id', '--nictype1', 'virtio' ]
```

**All provider options (VirtualBox):**

| Option      | Type    | Default                      | Description                                    |
|-------------|---------|------------------------------|------------------------------------------------|
| `type`      | string  | `virtualbox`                 | Provider type                                  |
| `name`      | string  | `{env}-{cluster}-{guest-id}` | VM name (used as Vagrant machine name)         |
| `group-id`  | string  | `{env}/{cluster}`            | VirtualBox group for organizing VMs            |
| `mem`       | number  | `2048`                       | Memory in MB                                   |
| `cpus`      | number  | `2`                          | Number of CPUs                                 |
| `gui`       | boolean | `false`                      | Show VirtualBox GUI                            |
| `customize` | array   | -                            | VirtualBox customize commands (modifyvm, etc.) |

## Network

```yaml
# Hostname at guest level (default: {guest-id}.{cluster}.{env})
hostname: node.local

network:
  private-network:
    enabled: true
    type: dhcp                    # dhcp or static
    ip: 172.16.10.100             # For static type (single IP)
    netmask: 255.255.255.0
  public-network:
    enabled: true
    type: static
    ip: # Multiple IPs supported (creates multiple interfaces)
      - 192.168.10.100
      - 192.168.10.101
    bridge:
      - "en0: Wi-Fi"
      - "en0: Ethernet"
  forwarded-ports:
    - enabled: true
      guest: 80
      host: 8080
      protocol: tcp
```

**Private Network Options:**

| Option        | Type         | Default  | Description                                        |
|---------------|--------------|----------|----------------------------------------------------|
| `enabled`     | boolean      | -        | Enable private network                             |
| `type`        | string       | `static` | Network type: `dhcp` or `static`                   |
| `ip`          | string/array | -        | Static IP address(es); multiple creates interfaces |
| `netmask`     | string       | -        | Subnet mask (e.g., `255.255.255.0`)                |
| `auto-config` | boolean      | `true`   | Auto-configure network interface                   |

**Public Network Options:**

| Option                            | Type         | Default  | Description                      |
|-----------------------------------|--------------|----------|----------------------------------|
| `enabled`                         | boolean      | -        | Enable public network            |
| `type`                            | string       | `static` | Network type: `dhcp` or `static` |
| `ip`                              | string/array | -        | Static IP address(es)            |
| `netmask`                         | string       | -        | Subnet mask                      |
| `bridge`                          | string/array | -        | Bridge interface(s) on host      |
| `auto-config`                     | boolean      | `true`   | Auto-configure network interface |
| `use-dhcp-assigned-default-route` | boolean      | `false`  | Use DHCP-assigned default route  |

**Forwarded Ports Options:**

| Option         | Type    | Default | Description                             |
|----------------|---------|---------|-----------------------------------------|
| `enabled`      | boolean | -       | Enable this port forwarding             |
| `guest`        | number  | -       | Guest port (required)                   |
| `host`         | number  | -       | Host port (required)                    |
| `protocol`     | string  | `tcp`   | Protocol: `tcp` or `udp`                |
| `id`           | string  | -       | Unique identifier for this port forward |
| `auto-correct` | boolean | `false` | Auto-correct host port if collision     |

## Synced Folders

```yaml
synced-folders:
  basic:
    - enabled: true
      host: ./data                # Host path
      guest: /data                # Guest mount path
      create: true                # Create if not exists
      owner: vagrant
      group: vagrant
  nfs:
    - enabled: true
      host: ./nfs-data
      guest: /nfs-data
      nfs-version: 4
  smb:
    - enabled: true
      host: ./smb-data
      guest: /smb-data
      smb-host: 192.168.10.3
      smb-username: user
      smb-password: pass
```

## Provisions

```yaml
provisions:
  - name: setup                   # Provision name
    desc: 'Setup script'          # Description
    enabled: true
    type: shell                   # shell or file
    privileged: true              # Run as root (default: false)
    run: once                     # once, always, never
    phase: pre                    # pre (default) or post - for common provisions only
    inline: |                     # Inline script
      echo "Hello $MY_VAR"
    env: # Environment variables
      MY_VAR: "world"
    # Or use path:
    # path: ./scripts/setup.sh
    # args: arg1 arg2
```

**All Provision Options:**

| Option        | Type         | Default              | Description                                               |
|---------------|--------------|----------------------|-----------------------------------------------------------|
| `name`        | string       | -                    | Provision name                                            |
| `enabled`     | boolean      | `true`               | Enable this provision                                     |
| `type`        | string       | `shell`              | Provision type: `shell` or `file`                         |
| `privileged`  | boolean      | `false`              | Run as root                                               |
| `run`         | string       | `once`               | When to run: `once`, `always`, `never`                    |
| `phase`       | string       | `pre`                | Execution phase: `pre` or `post` (common provisions only) |
| `inline`      | string       | -                    | Inline script content                                     |
| `path`        | string       | -                    | External script path                                      |
| `args`        | string/array | -                    | Script arguments                                          |
| `env`         | hash         | -                    | Environment variables                                     |
| `before`      | string       | -                    | Run before specified provision                            |
| `after`       | string       | -                    | Run after specified provision                             |
| `keep-color`  | boolean      | `false`              | Preserve color output                                     |
| `upload-path` | string       | `/tmp/vagrant-shell` | Script upload path on guest                               |
| `reboot`      | boolean      | `false`              | Reboot after execution                                    |
| `reset`       | boolean      | `false`              | Reset SSH connection after execution                      |
| `sensitive`   | boolean      | `false`              | Hide output (for sensitive data)                          |
| `binary`      | boolean      | `false`              | Transfer script as binary                                 |

**Script Path Resolution:**

Relative paths are resolved using smart detection:

1. Check if path exists **relative to config directory**
2. If not found, check **relative to project root** (config directory's parent)
3. If neither exists, use config-relative path (Vagrant reports the error)

**Phase Field (common provisions only):**

The `phase` field controls when common provisions run:

- `pre` (default): Runs before guest provisions
- `post`: Runs after guest provisions

Execution order: `global-pre → cluster-pre → guest → cluster-post → global-post`

### Builtin Provisions

Builtin provisions use `radp:` prefix and come with sensible defaults.

| Name                              | Description                                        | Defaults                        |
|-----------------------------------|----------------------------------------------------|---------------------------------|
| `radp:crypto/gpg-import`          | Import GPG keys (public/secret) into user keyrings | `privileged: false, run: once`  |
| `radp:crypto/gpg-preset-passphrase` | Preset GPG passphrase in gpg-agent cache         | `privileged: false, run: once`  |
| `radp:git/clone`                  | Clone git repository (HTTPS or SSH)                | `privileged: false, run: once`  |
| `radp:nfs/external-nfs-mount` | Mount external NFS shares                          | `privileged: true, run: always` |
| `radp:ssh/host-trust`         | Add host SSH key to guest                          | `privileged: false, run: once`  |
| `radp:ssh/cluster-trust`      | Configure SSH trust between VMs                    | `privileged: true, run: once`   |
| `radp:time/chrony-sync`       | Configure chrony for time sync                     | `privileged: true, run: once`   |
| `radp:yadm/clone`             | Clone dotfiles repository using yadm               | `privileged: false, run: once`  |

**Usage:**

```yaml
provisions:
  # Import your own GPG key pair for yadm/git signing (GPG_USERS auto-detected)
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/secret-key.asc"
      GPG_PASSPHRASE_FILE: "/vagrant/.secrets/passphrase.txt"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"

  # Or just import a public key
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_PUBLIC_KEY_FILE: "/vagrant/keys/colleague.asc"
      GPG_TRUST_LEVEL: "4"

  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"

  - name: radp:ssh/host-trust
    enabled: true
    env:
      HOST_SSH_PUBLIC_KEY_FILE: "/vagrant/host_ssh_key.pub"

  - name: radp:ssh/cluster-trust
    enabled: true
    env:
      CLUSTER_SSH_KEY_DIR: "/vagrant/keys"
      SSH_USERS: "vagrant,root"

  - name: radp:time/chrony-sync
    enabled: true
    env:
      NTP_SERVERS: "ntp.aliyun.com,ntp1.aliyun.com"
      TIMEZONE: "Asia/Shanghai"
```

**Environment Variables:**

| Provision                     | Required                 | Optional (defaults)                                                     |
|-------------------------------|--------------------------|-------------------------------------------------------------------------|
| `radp:crypto/gpg-import`      | None (one key source)    | See [GPG Import Details](#gpg-import-provision-details) below           |
| `radp:nfs/external-nfs-mount` | `NFS_SERVER`, `NFS_ROOT` | None                                                                    |
| `radp:ssh/host-trust`         | None (one of below)      | `HOST_SSH_PUBLIC_KEY`, `HOST_SSH_PUBLIC_KEY_FILE`, `SSH_USERS`(vagrant) |
| `radp:ssh/cluster-trust`      | `CLUSTER_SSH_KEY_DIR`    | `SSH_USERS`(vagrant), `TRUSTED_HOST_PATTERN`(auto)                      |
| `radp:time/chrony-sync`       | None                     | `NTP_SERVERS`, `NTP_POOL`(pool.ntp.org), `TIMEZONE`, `SYNC_NOW`(true)   |

#### GPG Import Provision Details

The `radp:crypto/gpg-import` provision imports GPG keys into user keyrings. It supports both public and secret (private)
keys, with flexible trust configuration.

**GPG Basics:**

| Term        | Description                                                                   |
|-------------|-------------------------------------------------------------------------------|
| Public Key  | Can be shared freely. Used to encrypt data TO you or verify your signatures   |
| Secret Key  | Must be kept secure. Used to decrypt data or sign. Often passphrase-protected |
| Key ID      | Short identifier (e.g., `0xABCD1234`) - last 8/16 hex digits of fingerprint   |
| Trust Level | 2=unknown, 3=marginal, 4=full, 5=ultimate (your own key)                      |

**Environment Variables:**

| Variable                                 | Description                                 |
|------------------------------------------|---------------------------------------------|
| **Key Sources (at least one required):** |                                             |
| `GPG_PUBLIC_KEY`                         | Public key content (ASCII-armored block)    |
| `GPG_PUBLIC_KEY_FILE`                    | Path to public key file (.asc or .gpg)      |
| `GPG_KEY_ID`                             | Key ID to fetch from keyserver              |
| `GPG_SECRET_KEY_FILE`                    | Path to secret key file (.asc or .gpg)      |
| **Keyserver Options:**                   |                                             |
| `GPG_KEYSERVER`                          | Keyserver URL (default: `keys.openpgp.org`) |
| **Secret Key Options:**                  |                                             |
| `GPG_PASSPHRASE`                         | Passphrase for secret key import            |
| `GPG_PASSPHRASE_FILE`                    | Path to file containing passphrase          |
| **Trust Options (choose one):**          |                                             |
| `GPG_TRUST_LEVEL`                        | Trust level (2-5) for imported key          |
| `GPG_OWNERTRUST_FILE`                    | Path to ownertrust file for batch import    |
| **General:**                             |                                             |
| `GPG_USERS`                              | Target users (see GPG_USERS behavior below) |

**GPG_USERS Behavior:**

| privileged        | GPG_USERS | Behavior                                  |
|-------------------|-----------|-------------------------------------------|
| `false` (default) | Not set   | Auto-detect current user                  |
| `false` (default) | Set       | Ignored, uses current user (with warning) |
| `true`            | Not set   | **Error** — must specify target users     |
| `true`            | Set       | Uses specified users                      |

**Common Use Cases:**

```yaml
# Use case 1: yadm / git commit signing (import your own key pair)
# GPG_USERS not needed — auto-detects current user
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/secret-key.asc"
      GPG_PASSPHRASE_FILE: "/vagrant/.secrets/passphrase.txt"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"

# Use case 2: Verify signatures from a colleague
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_PUBLIC_KEY_FILE: "/vagrant/keys/colleague.asc"
      GPG_TRUST_LEVEL: "4"

# Use case 3: Fetch a key from keyserver
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_KEY_ID: "0x1234567890ABCDEF"
      GPG_KEYSERVER: "keys.openpgp.org"

# Use case 4: Import for multiple users (requires privileged)
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    privileged: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/secret-key.asc"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"
      GPG_USERS: "vagrant,root"
```

**How to Export Your Keys (run on host):**

```bash
# 1. Find your key ID
gpg --list-secret-keys --keyid-format LONG

# 2. Export secret key (includes public key)
gpg --export-secret-keys --armor YOUR_KEY_ID >secret-key.asc

# 3. Export ownertrust
gpg --export-ownertrust >ownertrust.txt

# 4. Store passphrase (if key is protected)
echo "your-passphrase" >passphrase.txt
```

**Security Note:** Store exported keys securely. Consider using Vagrant synced folders with restricted permissions.

#### GPG Preset Passphrase Provision Details

The `radp:crypto/gpg-preset-passphrase` provision caches the GPG passphrase in gpg-agent for non-interactive operations.

**Why Preset Passphrase?**

By default, GPG prompts for your passphrase every time you use your secret key. This is problematic for:

- `yadm decrypt`
- `git commit --gpg-sign`
- Automated encryption/decryption scripts

**Prerequisites:**

1. Secret key must be imported first (use `radp:crypto/gpg-import`)
2. `gpg-agent.conf` must have `allow-preset-passphrase` (auto-configured by default)

**Environment Variables:**

| Variable                 | Description                                          |
|--------------------------|------------------------------------------------------|
| **Required:**            |                                                      |
| `GPG_KEY_UID`            | Key UID (email) to identify the key                  |
| **Passphrase (one required):** |                                                |
| `GPG_PASSPHRASE`         | Passphrase content                                   |
| `GPG_PASSPHRASE_FILE`    | Path to file containing passphrase                   |
| **Options:**             |                                                      |
| `GPG_AGENT_ALLOW_PRESET` | Auto-configure gpg-agent.conf (default: true)        |
| **General:**             |                                                      |
| `GPG_USERS`              | Target users (auto-detected when unprivileged)       |

**Common Use Cases:**

```yaml
# Complete workflow: import key, preset passphrase, clone with decrypt
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/gpg-key.asc"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"

  - name: radp:crypto/gpg-preset-passphrase
    enabled: true
    env:
      GPG_KEY_UID: "user@example.com"
      GPG_PASSPHRASE_FILE: "/vagrant/.secrets/passphrase.txt"

  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@github.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
      YADM_DECRYPT: "true"  # Will work without passphrase prompt
```

#### Git Clone Provision Details

The `radp:git/clone` provision clones git repositories with HTTPS or SSH authentication.

**Environment Variables:**

| Variable                              | Description                                          |
|---------------------------------------|------------------------------------------------------|
| **Required:**                         |                                                      |
| `GIT_REPO_URL`                        | Repository URL (HTTPS or SSH format)                 |
| **Target Options:**                   |                                                      |
| `GIT_CLONE_DIR`                       | Target directory (default: ~/repo-name)              |
| `GIT_CLONE_OPTIONS`                   | Additional git clone options (e.g., `--depth 1`)     |
| **HTTPS Authentication:**             |                                                      |
| `GIT_HTTPS_USER`                      | Username for HTTPS auth                              |
| `GIT_HTTPS_TOKEN`                     | Personal access token                                |
| `GIT_HTTPS_TOKEN_FILE`                | Path to file containing token                        |
| **SSH Options:**                      |                                                      |
| `GIT_SSH_KEY_FILE`                    | Path to SSH private key file                         |
| `GIT_SSH_HOST`                        | Override SSH hostname/IP (for DNS issues)            |
| `GIT_SSH_PORT`                        | Override SSH port (default: 22)                      |
| `GIT_SSH_STRICT_HOST_KEY`             | Strict host key checking (default: false)            |
| **General:**                          |                                                      |
| `GIT_SKIP_IF_EXISTS`                  | Skip if directory exists (default: true)             |
| `GIT_USERS`                           | Target users (auto-detected when unprivileged)       |

**Common Use Cases:**

```yaml
# HTTPS clone (public repo)
provisions:
  - name: radp:git/clone
    enabled: true
    env:
      GIT_REPO_URL: "https://github.com/user/repo.git"

# HTTPS clone (private repo with token)
provisions:
  - name: radp:git/clone
    enabled: true
    env:
      GIT_REPO_URL: "https://github.com/user/private-repo.git"
      GIT_HTTPS_TOKEN_FILE: "/vagrant/.secrets/github-token"

# SSH clone (with key)
provisions:
  - name: radp:git/clone
    enabled: true
    env:
      GIT_REPO_URL: "git@github.com:user/repo.git"
      GIT_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"

# SSH clone (private GitLab with DNS override)
provisions:
  - name: radp:git/clone
    enabled: true
    env:
      GIT_REPO_URL: "git@gitlab.example.com:group/repo.git"
      GIT_SSH_KEY_FILE: "/mnt/ssh/id_rsa_gitlab"
      GIT_SSH_HOST: "192.168.20.35"
```

#### yadm Clone Provision Details

The `radp:yadm/clone` provision clones dotfiles repositories using [yadm](https://yadm.io/) (Yet Another Dotfiles Manager).

**What is yadm?**

yadm is a dotfiles manager that wraps around git:

- Tracks files in `$HOME` without moving them
- Stores repo in `~/.local/share/yadm/repo.git`
- Supports encrypted files (via GPG)
- Supports alternate files per host/class/OS
- Has bootstrap script for automated setup

**Environment Variables:**

| Variable                              | Description                                          |
|---------------------------------------|------------------------------------------------------|
| **Required:**                         |                                                      |
| `YADM_REPO_URL`                       | Dotfiles repository URL (HTTPS or SSH)               |
| **yadm Options:**                     |                                                      |
| `YADM_BOOTSTRAP`                      | Run bootstrap after clone (default: false)           |
| `YADM_DECRYPT`                        | Run decrypt after clone (default: false, needs GPG)  |
| `YADM_CLASS`                          | Set yadm class before clone                          |
| **HTTPS Authentication:**             |                                                      |
| `YADM_HTTPS_USER`                     | Username for HTTPS auth                              |
| `YADM_HTTPS_TOKEN`                    | Personal access token                                |
| `YADM_HTTPS_TOKEN_FILE`               | Path to file containing token                        |
| **SSH Options:**                      |                                                      |
| `YADM_SSH_KEY_FILE`                   | Path to SSH private key file                         |
| `YADM_SSH_HOST`                       | Override SSH hostname/IP (for DNS issues)            |
| `YADM_SSH_PORT`                       | Override SSH port (default: 22)                      |
| `YADM_SSH_STRICT_HOST_KEY`            | Strict host key checking (default: false)            |
| **General:**                          |                                                      |
| `YADM_USERS`                          | Target users (auto-detected when unprivileged)       |

**Common Use Cases:**

```yaml
# Basic yadm clone (HTTPS)
provisions:
  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "https://github.com/user/dotfiles.git"

# SSH clone with bootstrap
provisions:
  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@github.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
      YADM_BOOTSTRAP: "true"

# Private GitLab with GPG decryption
# (requires radp:crypto/gpg-import first)
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/gpg-key.asc"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"

  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@gitlab.example.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/mnt/ssh/id_rsa_gitlab"
      YADM_SSH_HOST: "192.168.20.35"
      YADM_DECRYPT: "true"
```

### User Provisions

Define reusable provisions with `user:` prefix in your project.

**Directory structure:**

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

**Definition format:**

```yaml
# config/provisions/definitions/docker/setup.yaml
description: Install and configure Docker
defaults:
  privileged: true
  run: once
required_env:
  - DOCKER_VERSION
script: setup.sh
```

**Usage:**

```yaml
provisions:
  - name: user:docker/setup
    enabled: true
    env:
      DOCKER_VERSION: "24.0"
```

## Triggers

Note: The `on` key must be quoted in YAML to prevent parsing as boolean.

```yaml
triggers:
  - name: before-up               # Trigger name
    desc: 'Pre-start trigger'     # Description
    enabled: true
    "on": before                  # before or after (must be quoted!)
    type: action                  # action, command, hook
    action: # Actions to trigger on
      - up
      - reload
    only-on: # Filter guests (supports regex)
      - '/node-.*/'
    run:
      inline: |                   # Local script
        echo "Starting..."
    # Or run-remote for guest execution
```

**All Trigger Options:**

| Option     | Type         | Default  | Description                                        |
|------------|--------------|----------|----------------------------------------------------|
| `name`     | string       | -        | Trigger name                                       |
| `enabled`  | boolean      | `true`   | Enable this trigger                                |
| `"on"`     | string       | `before` | Timing: `before` or `after` (must be quoted!)      |
| `type`     | string       | `action` | Scope: `action`, `command`, or `hook`              |
| `action`   | string/array | `[:up]`  | Actions/commands to trigger on                     |
| `only-on`  | string/array | -        | Filter by machine name; supports regex `/pattern/` |
| `ignore`   | string/array | -        | Actions to ignore                                  |
| `on-error` | string       | -        | Error behavior: `:halt`, `:continue`               |
| `abort`    | boolean      | `false`  | Abort Vagrant operation if trigger fails           |
| `desc`     | string       | -        | Description displayed before trigger runs          |
| `warn`     | string       | -        | Warning message displayed before trigger           |

**Run options (local execution):**

| Option   | Type         | Description                  |
|----------|--------------|------------------------------|
| `inline` | string       | Inline script to run on host |
| `path`   | string       | Script path on host          |
| `args`   | string/array | Arguments to pass to script  |

**Run-remote options (guest execution):**

| Option   | Type         | Description                             |
|----------|--------------|-----------------------------------------|
| `inline` | string       | Inline script to run on guest           |
| `path`   | string       | Script path on host (uploaded to guest) |
| `args`   | string/array | Arguments to pass to script             |

### Builtin Triggers

| Name                            | Description                               | Default Timing  |
|---------------------------------|-------------------------------------------|-----------------|
| `radp:system/disable-swap`      | Disable swap partition (required for K8s) | after up/reload |
| `radp:system/disable-selinux`   | Disable SELinux (set to permissive mode)  | after up/reload |
| `radp:system/disable-firewalld` | Disable firewalld service                 | after up/reload |

**Usage:**

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true

  - name: radp:system/disable-selinux
    enabled: true

  - name: radp:system/disable-firewalld
    enabled: true
```

## Plugins

Plugins are configured in the `plugins` array:

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true                # Auto-install if missing
    options:
      enabled: true
```

Supported plugins:

- `vagrant-hostmanager` - Host file management
- `vagrant-vbguest` - VirtualBox Guest Additions
- `vagrant-proxyconf` - Proxy configuration
- `vagrant-bindfs` - Bind mounts (per synced-folder)

### vagrant-hostmanager

Manages `/etc/hosts` on host and guest machines.

**Basic configuration:**

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      enabled: true               # Update hosts on vagrant up/destroy
      manage_host: true           # Update host machine's /etc/hosts
      manage_guest: true          # Update guest machines' /etc/hosts
      include_offline: false      # Include offline VMs
```

**Provisioner mode:**

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled        # Run as provisioner instead of automatically
      manage_host: true
      manage_guest: true
```

> Note: `provisioner` and `enabled` are mutually exclusive.

**Custom IP resolver:**

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      manage_host: true
      ip_resolver:
        enabled: true
        execute: "hostname -I"    # Command to run on guest
        regex: "^(\\S+)"          # Regex to extract IP
```

**Per-guest settings:**

```yaml
hostmanager:
  aliases:
    - myhost.local
    - myhost
  ip-resolver:
    enabled: true
    execute: "hostname -I | cut -d ' ' -f 2"
    regex: "^(\\S+)"
```

### vagrant-vbguest

Automatically installs VirtualBox Guest Additions.

**Recommended configuration:**

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      auto_update: true
      auto_reboot: true
```

**Distribution-specific:**

```yaml
# CentOS/RHEL
plugins:
  - name: vagrant-vbguest
    options:
      installer: centos
      auto_update: true
      auto_reboot: true
      installer_options:
        allow_kernel_upgrade: true
        reboot_timeout: 300
```

**All options:**

| Option              | Type    | Default | Description                     |
|---------------------|---------|---------|---------------------------------|
| `auto_update`       | boolean | `true`  | Check/update on VM start        |
| `no_remote`         | boolean | `false` | Prevent downloading ISO         |
| `no_install`        | boolean | `false` | Only check version              |
| `auto_reboot`       | boolean | `true`  | Reboot after installation       |
| `allow_downgrade`   | boolean | `true`  | Allow installing older versions |
| `iso_path`          | string  | -       | Custom ISO path                 |
| `installer`         | string  | auto    | Installer type                  |
| `installer_options` | hash    | -       | Distro-specific options         |

### vagrant-bindfs

Fixes NFS permission issues by remapping user/group ownership.

**Per-folder configuration:**

```yaml
synced-folders:
  nfs:
    - host: ./data
      guest: /data
      bindfs:
        enabled: true
        force_user: vagrant
        force_group: vagrant
```

**With permission mapping:**

```yaml
synced-folders:
  nfs:
    - host: ./app
      guest: /var/www/app
      bindfs:
        enabled: true
        force_user: www-data
        force_group: www-data
        perms: "u=rwX:g=rX:o=rX"
        create_with_perms: "u=rwX:g=rX:o=rX"
```

**Global options:**

```yaml
plugins:
  - name: vagrant-bindfs
    options:
      debug: false
      force_empty_mountpoints: true
      skip_validations:
        - user
        - group
      default_options:
        force_user: vagrant
        force_group: vagrant
```
