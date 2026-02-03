# Builtin Triggers Reference

Complete reference for all builtin triggers (`radp:` prefix).

## Overview

| Name                            | Description            | Default Timing  |
|---------------------------------|------------------------|-----------------|
| `radp:system/disable-swap`      | Disable swap partition | after up/reload |
| `radp:system/disable-selinux`   | Disable SELinux        | after up/reload |
| `radp:system/disable-firewalld` | Disable firewalld      | after up/reload |

## radp:system/disable-swap

Disable swap partition (required for Kubernetes).

### Usage

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true
```

### What it Does

Runs on guest after `vagrant up` or `vagrant reload`:

```bash
swapoff -a
sed -i '/swap/d' /etc/fstab
```

## radp:system/disable-selinux

Disable SELinux (set to permissive mode).

### Usage

```yaml
triggers:
  - name: radp:system/disable-selinux
    enabled: true
```

### What it Does

Runs on guest after `vagrant up` or `vagrant reload`:

```bash
setenforce 0 || true
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

## radp:system/disable-firewalld

Disable firewalld service.

### Usage

```yaml
triggers:
  - name: radp:system/disable-firewalld
    enabled: true
```

### What it Does

Runs on guest after `vagrant up` or `vagrant reload`:

```bash
systemctl stop firewalld
systemctl disable firewalld
```

## Combined Example

Common setup for Kubernetes nodes:

```yaml
common:
  triggers:
    - name: radp:system/disable-swap
      enabled: true
    - name: radp:system/disable-selinux
      enabled: true
    - name: radp:system/disable-firewalld
      enabled: true
```

## See Also

- [Triggers Guide](../user-guide/triggers.md) - How to use triggers
- [Extending](../developer/extending.md) - Add custom builtin triggers
