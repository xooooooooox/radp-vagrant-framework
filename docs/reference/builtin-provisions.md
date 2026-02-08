# Builtin Provisions Reference

Complete reference for all builtin provisions (`radp:` prefix).

## Overview

| Name                                | Description               | Defaults                        |
|-------------------------------------|---------------------------|---------------------------------|
| `radp:crypto/gpg-import`            | Import GPG keys           | `privileged: false, run: once`  |
| `radp:crypto/gpg-preset-passphrase` | Preset GPG passphrase     | `privileged: false, run: once`  |
| `radp:git/clone`                    | Clone git repository      | `privileged: false, run: once`  |
| `radp:nfs/external-nfs-mount`       | Mount external NFS shares | `privileged: true, run: always` |
| `radp:ssh/host-trust`               | Add host SSH key to guest | `privileged: false, run: once`  |
| `radp:ssh/cluster-trust`            | SSH trust between VMs     | `privileged: true, run: once`   |
| `radp:ssh/target-trust`            | SSH trust with ext. target | `privileged: false, run: once` |
| `radp:system/expand-lvm`            | Expand LVM partition      | `privileged: true, run: once`   |
| `radp:time/chrony-sync`             | Configure time sync       | `privileged: true, run: once`   |
| `radp:yadm/clone`                   | Clone dotfiles with yadm  | `privileged: false, run: once`  |
| `radp:yadm/bootstrap`              | Run yadm bootstrap        | `privileged: false, run: once`  |
| `radp:yadm/submodules`              | Init yadm submodules      | `privileged: false, run: once`  |

## radp:crypto/gpg-import

Import GPG keys (public/secret) into user keyrings.

### GPG Basics

| Term        | Description                                                                   |
|-------------|-------------------------------------------------------------------------------|
| Public Key  | Can be shared freely. Used to encrypt data TO you or verify signatures        |
| Secret Key  | Must be kept secure. Used to decrypt data or sign. Often passphrase-protected |
| Key ID      | Short identifier (e.g., `0xABCD1234`) - last 8/16 hex digits of fingerprint   |
| Trust Level | 2=unknown, 3=marginal, 4=full, 5=ultimate (your own key)                      |

### Environment Variables

**Key Sources (at least one required):**

| Variable              | Description                        |
|-----------------------|------------------------------------|
| `GPG_PUBLIC_KEY`      | Public key content (ASCII-armored) |
| `GPG_PUBLIC_KEY_FILE` | Path to public key file            |
| `GPG_KEY_ID`          | Key ID to fetch from keyserver     |
| `GPG_SECRET_KEY_FILE` | Path to secret key file            |

**Options:**

| Variable              | Description                                 |
|-----------------------|---------------------------------------------|
| `GPG_KEYSERVER`       | Keyserver URL (default: `keys.openpgp.org`) |
| `GPG_PASSPHRASE`      | Passphrase for secret key                   |
| `GPG_PASSPHRASE_FILE` | Path to passphrase file                     |
| `GPG_TRUST_LEVEL`     | Trust level (2-5)                           |
| `GPG_OWNERTRUST_FILE` | Path to ownertrust file                     |
| `GPG_USERS`           | Target users (comma-separated)              |

### GPG_USERS Behavior

| privileged        | GPG_USERS | Behavior                                  |
|-------------------|-----------|-------------------------------------------|
| `false` (default) | Not set   | Auto-detect current user                  |
| `false` (default) | Set       | Ignored, uses current user (with warning) |
| `true`            | Not set   | **Error** — must specify target users     |
| `true`            | Set       | Uses specified users                      |

### Examples

```yaml
# Import your own key pair (for yadm/git signing)
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/secret-key.asc"
      GPG_PASSPHRASE_FILE: "/vagrant/.secrets/passphrase.txt"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"

# Import a colleague's public key
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_PUBLIC_KEY_FILE: "/vagrant/keys/colleague.asc"
      GPG_TRUST_LEVEL: "4"

# Fetch key from keyserver
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_KEY_ID: "0x1234567890ABCDEF"
      GPG_KEYSERVER: "keys.openpgp.org"

# Import for multiple users (requires privileged)
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    privileged: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/secret-key.asc"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"
      GPG_USERS: "vagrant,root"
```

### How to Export Your Keys

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

## radp:crypto/gpg-preset-passphrase

Preset GPG passphrase in gpg-agent for non-interactive operations.

### Why Preset Passphrase?

By default, GPG prompts for your passphrase every time you use your secret key. This is problematic for:

- `yadm decrypt`
- `git commit --gpg-sign`
- Automated encryption/decryption scripts

### Prerequisites

1. Secret key must be imported first (use `radp:crypto/gpg-import`)
2. `gpg-agent.conf` must have `allow-preset-passphrase` (auto-configured by default)

### Environment Variables

| Variable                 | Description                                    |
|--------------------------|------------------------------------------------|
| `GPG_KEY_UID`            | Key UID (email) to identify the key (required) |
| `GPG_PASSPHRASE`         | Passphrase content                             |
| `GPG_PASSPHRASE_FILE`    | Path to passphrase file                        |
| `GPG_AGENT_ALLOW_PRESET` | Auto-configure gpg-agent (default: true)       |
| `GPG_USERS`              | Target users                                   |

### Example

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

## radp:git/clone

Clone git repositories with HTTPS or SSH authentication.

### Environment Variables

| Variable                  | Description                               |
|---------------------------|-------------------------------------------|
| `GIT_REPO_URL`            | Repository URL (required)                 |
| `GIT_CLONE_DIR`           | Target directory (default: ~/repo-name)   |
| `GIT_CLONE_OPTIONS`       | Additional git clone options              |
| `GIT_HTTPS_USER`          | Username for HTTPS auth                   |
| `GIT_HTTPS_TOKEN`         | Personal access token                     |
| `GIT_HTTPS_TOKEN_FILE`    | Path to token file                        |
| `GIT_SSH_KEY_FILE`        | Path to SSH private key                   |
| `GIT_SSH_HOST`            | Override SSH hostname                     |
| `GIT_SSH_PORT`            | Override SSH port                         |
| `GIT_SSH_STRICT_HOST_KEY` | Strict host key checking (default: false) |
| `GIT_SKIP_IF_EXISTS`      | Skip if directory exists (default: true)  |
| `GIT_USERS`               | Target users                              |

### Examples

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

## radp:nfs/external-nfs-mount

Mount external NFS shares.

### Environment Variables

| Variable     | Description                    |
|--------------|--------------------------------|
| `NFS_SERVER` | NFS server hostname (required) |
| `NFS_ROOT`   | NFS root path (required)       |

### Example

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"
```

## radp:ssh/host-trust

Add host SSH public key to guest authorized_keys.

### Environment Variables

| Variable                   | Description                     |
|----------------------------|---------------------------------|
| `HOST_SSH_PUBLIC_KEY`      | Public key content              |
| `HOST_SSH_PUBLIC_KEY_FILE` | Path to public key file         |
| `SSH_USERS`                | Target users (default: vagrant) |

### Example

```yaml
provisions:
  - name: radp:ssh/host-trust
    enabled: true
    env:
      HOST_SSH_PUBLIC_KEY_FILE: "/vagrant/host_ssh_key.pub"
```

## radp:ssh/cluster-trust

Configure SSH trust between VMs in a cluster.

### Environment Variables

| Variable               | Description                              |
|------------------------|------------------------------------------|
| `CLUSTER_SSH_KEY_DIR`  | Directory containing SSH keys (required) |
| `SSH_USERS`            | Target users (default: vagrant)          |
| `TRUSTED_HOST_PATTERN` | Pattern for trusted hosts (auto)         |

### Example

```yaml
provisions:
  - name: radp:ssh/cluster-trust
    enabled: true
    env:
      CLUSTER_SSH_KEY_DIR: "/vagrant/keys"
      SSH_USERS: "vagrant,root"
```

## radp:ssh/target-trust

Establish SSH trust between a guest VM and a specified external target (e.g., GitLab server, bastion host, deploy server).

Configures the **guest side** of SSH trust:
- **Outbound** (guest -> target): deploy private key + SSH config + known_hosts
- **Inbound** (target -> guest): add target's public key to authorized_keys

Each direction is independently optional.

### Environment Variables

**Required:**

| Variable      | Description                  |
|---------------|------------------------------|
| `TARGET_HOST` | Target hostname or IP address |

**Outbound (guest -> target):**

| Variable                    | Description                                                |
|-----------------------------|------------------------------------------------------------|
| `TARGET_SSH_PRIVATE_KEY_FILE` | Path to private key file for authenticating to the target |
| `TARGET_KEY_NAME`           | Custom key name in ~/.ssh/ (default: `id_target_{sanitized_host}`) |
| `TARGET_SSH_USER`           | Username on the target (for SSH config entry)              |
| `TARGET_SSH_PORT`           | SSH port on the target                                     |
| `TARGET_HOST_ALIAS`        | Host alias for SSH config entry (default: `TARGET_HOST`)   |

**Known hosts (choose one):**

| Variable              | Description                                                    |
|-----------------------|----------------------------------------------------------------|
| `TARGET_HOST_KEY`     | Target host key content for known_hosts                        |
| `TARGET_HOST_KEY_FILE` | Path to file containing target host key(s) for known_hosts    |
| `TARGET_KEYSCAN`      | Attempt ssh-keyscan to fetch target host keys (default: false) |

**Known hosts behavior:**

| Priority | Source               | Behavior                                                          |
|----------|----------------------|-------------------------------------------------------------------|
| 1st      | `TARGET_HOST_KEY`    | Add to known_hosts, SSH config -> `StrictHostKeyChecking yes`     |
| 2nd      | `TARGET_HOST_KEY_FILE` | Append file to known_hosts, SSH config -> `StrictHostKeyChecking yes` |
| 3rd      | `TARGET_KEYSCAN=true` | Run ssh-keyscan; on success -> strict; on failure -> warn + fallback |
| Fallback | None of above        | SSH config -> `StrictHostKeyChecking no` + `UserKnownHostsFile /dev/null` |

**Inbound (target -> guest):**

| Variable               | Description                                          |
|------------------------|------------------------------------------------------|
| `TARGET_PUBLIC_KEY`    | Target's SSH public key content (for authorized_keys) |
| `TARGET_PUBLIC_KEY_FILE` | Path to file containing target's SSH public key     |

**General:**

| Variable    | Description                             |
|-------------|-----------------------------------------|
| `SSH_USERS` | Target users (default: vagrant)         |

### Examples

```yaml
# Outbound only: guest can SSH to GitLab
provisions:
  - name: radp:ssh/target-trust
    enabled: true
    env:
      TARGET_HOST: "gitlab.example.com"
      TARGET_SSH_PRIVATE_KEY_FILE: "/vagrant/.secrets/id_rsa_gitlab"
      TARGET_KEYSCAN: "true"

# Bidirectional: guest <-> deploy server
provisions:
  - name: radp:ssh/target-trust
    enabled: true
    env:
      TARGET_HOST: "deploy.example.com"
      TARGET_SSH_PRIVATE_KEY_FILE: "/vagrant/.secrets/id_rsa_deploy"
      TARGET_HOST_KEY_FILE: "/vagrant/.secrets/deploy_host_key"
      TARGET_PUBLIC_KEY_FILE: "/vagrant/.secrets/deploy_user_key.pub"
      TARGET_SSH_USER: "deployer"

# Inbound only: allow CI server to SSH into guest
provisions:
  - name: radp:ssh/target-trust
    enabled: true
    env:
      TARGET_HOST: "ci.example.com"
      TARGET_PUBLIC_KEY_FILE: "/vagrant/.secrets/ci_user_key.pub"

# Multiple targets (use multiple provision entries)
provisions:
  - name: radp:ssh/target-trust
    enabled: true
    env:
      TARGET_HOST: "gitlab.example.com"
      TARGET_SSH_PRIVATE_KEY_FILE: "/vagrant/.secrets/id_rsa_gitlab"
      TARGET_HOST_KEY_FILE: "/vagrant/.secrets/gitlab_host_key"
  - name: radp:ssh/target-trust
    enabled: true
    env:
      TARGET_HOST: "bastion.example.com"
      TARGET_SSH_PRIVATE_KEY_FILE: "/vagrant/.secrets/id_rsa_bastion"
      TARGET_SSH_USER: "admin"
      TARGET_SSH_PORT: "2222"
      TARGET_KEYSCAN: "true"
```

## radp:system/expand-lvm

Expand LVM partition and filesystem to use all available disk space.

### When to Use

This is needed when using `vagrant-disksize` plugin to resize the virtual disk. The plugin only resizes the virtual
disk, but the partition table and LVM volumes are not automatically expanded.

### What it Does

1. Installs `growpart` (from `cloud-guest-utils` or `cloud-utils-growpart`)
2. Expands the partition using `growpart`
3. Resizes the physical volume using `pvresize`
4. Extends the logical volume using `lvextend`
5. Resizes the filesystem using `resize2fs` (ext4) or `xfs_growfs` (xfs)

### Environment Variables

| Variable        | Description                       |
|-----------------|-----------------------------------|
| `LVM_PARTITION` | LVM partition (auto-detected)     |
| `LVM_VG`        | Volume group name (auto-detected) |
| `LVM_LV`        | Logical volume (auto-detected)    |
| `DRY_RUN`       | Preview changes (default: false)  |

### Example

```yaml
guests:
  - id: master
    disk_size: 50GB
    box:
      name: ubuntu/jammy64
    provisions:
      - name: radp:system/expand-lvm
        enabled: true
```

### Before/After

**Before:**

```
$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0   50G  0 disk
├─sda1                      8:1    0  538M  0 part /boot/efi
├─sda2                      8:2    0  1.8G  0 part /boot
└─sda3                      8:3    0  7.7G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0  7.7G  0 lvm  /
```

**After:**

```
$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0   50G  0 disk
├─sda1                      8:1    0  538M  0 part /boot/efi
├─sda2                      8:2    0  1.8G  0 part /boot
└─sda3                      8:3    0 47.7G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0 47.7G  0 lvm  /
```

## radp:time/chrony-sync

Configure chrony for time synchronization.

### Environment Variables

| Variable      | Description                      |
|---------------|----------------------------------|
| `NTP_SERVERS` | NTP servers (comma-separated)    |
| `NTP_POOL`    | NTP pool (default: pool.ntp.org) |
| `TIMEZONE`    | Timezone to set                  |
| `SYNC_NOW`    | Sync immediately (default: true) |

### Example

```yaml
provisions:
  - name: radp:time/chrony-sync
    enabled: true
    env:
      NTP_SERVERS: "ntp.aliyun.com,ntp1.aliyun.com"
      TIMEZONE: "Asia/Shanghai"
```

## radp:yadm/clone

Clone dotfiles repository using yadm.

### What is yadm?

yadm is a dotfiles manager that wraps around git:

- Tracks files in `$HOME` without moving them
- Stores repo in `~/.local/share/yadm/repo.git`
- Supports encrypted files (via GPG)
- Supports alternate files per host/class/OS
- Has bootstrap script for automated setup

### Environment Variables

| Variable                   | Description                               |
|----------------------------|-------------------------------------------|
| `YADM_REPO_URL`            | Repository URL (required)                 |
| `YADM_DECRYPT`             | Run decrypt (default: false)              |
| `YADM_CLASS`               | Set yadm class                            |
| `YADM_HTTPS_USER`          | Username for HTTPS                        |
| `YADM_HTTPS_TOKEN`         | Access token                              |
| `YADM_HTTPS_TOKEN_FILE`    | Path to token file                        |
| `YADM_SSH_KEY_FILE`        | Path to SSH key                           |
| `YADM_SSH_HOST`            | Override SSH hostname                     |
| `YADM_SSH_PORT`            | Override SSH port                         |
| `YADM_SSH_STRICT_HOST_KEY` | Strict host key checking (default: false) |
| `YADM_USERS`               | Target users                              |

### Examples

```yaml
# Basic yadm clone (HTTPS)
provisions:
  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "https://github.com/user/dotfiles.git"

# SSH clone
provisions:
  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@github.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"

# Private GitLab with GPG decryption
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

### Execution Order

When `radp:yadm/clone` runs, it performs the following steps in order for each user:

1. **Set class** — `yadm config local.class` (if `YADM_CLASS` is set)
2. **Clone** — `yadm clone --no-bootstrap`
3. **Decrypt** — `yadm decrypt` (if `YADM_DECRYPT=true`)

Step 2 propagates `GIT_SSH_COMMAND` with full SSH options (including `YADM_SSH_HOST`
and `YADM_SSH_PORT` overrides) when using SSH repositories. Step 3 (decrypt) is a
local GPG operation and does not use SSH.

> **Note:** Submodule initialization and bootstrap are handled by separate provisions
> (`radp:yadm/submodules` and `radp:yadm/bootstrap`). This gives you full control over
> execution order — e.g. running submodules after decrypt, or bootstrap after submodules.

## radp:yadm/bootstrap

Run yadm bootstrap on an already-cloned yadm repository. Extracted as a standalone provision
so you can control when bootstrap runs — for example, after submodules are initialized.

`yadm bootstrap` executes a local script (`~/.config/yadm/bootstrap`) — it does not perform
any git/SSH operations itself, so no SSH options are needed.

### Prerequisites

A yadm repository must already be cloned (via `radp:yadm/clone`).

### Environment Variables

| Variable     | Description  |
|--------------|--------------|
| `YADM_USERS` | Target users |

### Examples

```yaml
# Bootstrap after clone
provisions:
  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@github.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"

  - name: radp:yadm/bootstrap
    enabled: true

# Full workflow: clone → decrypt → submodules → bootstrap
provisions:
  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@github.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
      YADM_DECRYPT: "true"

  - name: radp:yadm/submodules
    enabled: true
    env:
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"

  - name: radp:yadm/bootstrap
    enabled: true
```

## radp:yadm/submodules

Initialize and update yadm submodules. Extracted as a standalone provision so you can control
when submodules run — for example, after `yadm decrypt` when `.gitmodules` depends on decrypted files.

### Prerequisites

A yadm repository must already be cloned (via `radp:yadm/clone`).

### Environment Variables

| Variable                   | Description                               |
|----------------------------|-------------------------------------------|
| `YADM_SSH_KEY_FILE`        | Path to SSH key                           |
| `YADM_SSH_STRICT_HOST_KEY` | Strict host key checking (default: false) |
| `YADM_USERS`               | Target users                              |

> **Note:** No host overrides (`YADM_SSH_HOST`/`YADM_SSH_PORT`) — submodules may be hosted
> on different servers than the main yadm repository.

### Examples

```yaml
# Basic: submodules right after clone
provisions:
  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@github.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"

  - name: radp:yadm/submodules
    enabled: true
    env:
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"

# Advanced: submodules after decrypt (when .gitmodules depends on decrypted files)
provisions:
  - name: radp:crypto/gpg-import
    enabled: true
    env:
      GPG_SECRET_KEY_FILE: "/vagrant/.secrets/gpg-key.asc"
      GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"

  - name: radp:yadm/clone
    enabled: true
    env:
      YADM_REPO_URL: "git@github.com:user/dotfiles.git"
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
      YADM_DECRYPT: "true"

  - name: radp:yadm/submodules
    enabled: true
    env:
      YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
```

## See Also

- [Provisions Guide](../user-guide/provisions.md) - How to use provisions
- [Extending](../developer/extending.md) - Add custom builtin provisions
