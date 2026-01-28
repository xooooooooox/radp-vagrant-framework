# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

[![CI](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/ci.yml?label=CI)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/ci.yml)
[![CI: Homebrew](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/update-homebrew-tap.yml?label=Homebrew%20tap)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/update-homebrew-tap.yml)

基于 YAML 配置的多机 Vagrant 环境管理框架，支持配置继承和模块化配置脚本。

## 特性

- **声明式 YAML 配置** - 通过 YAML 定义虚拟机、网络、配置脚本和触发器
- **多文件配置** - 基础配置 + 环境特定覆盖（`vagrant.yaml` + `vagrant-{env}.yaml`）
- **配置继承** - Global → Cluster → Guest 三级继承，自动合并
- **随处运行** - 无需 `cd` 到 Vagrantfile 目录，使用 `-c` 参数可从任意位置运行命令
- **模板系统** - 通过预定义模板初始化项目（`base`、`single-node`、`k8s-cluster`）
- **内置 Provisions & Triggers** - 使用 `radp:` 前缀的可复用组件
- **插件支持** - vagrant-hostmanager、vagrant-vbguest、vagrant-proxyconf、vagrant-bindfs
- **约定优于配置** - 自动生成 hostname、provider name 和 group-id
- **调试支持** - 导出合并后的配置，生成独立 Vagrantfile 用于检查

## 前置要求

- Ruby 2.7+
- Vagrant 2.0+
- VirtualBox（或其他支持的 provider）

## 安装

### Homebrew（推荐）

```shell
brew tap xooooooooox/radp
brew install radp-vagrant-framework
```

### 脚本安装 (curl)

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh | bash
```

从指定分支或标签安装：

```shell
bash install.sh --ref main
bash install.sh --ref v1.0.0-rc1
```

更多安装选项（手动安装、升级、Shell 补全）请参阅[安装指南](docs/installation.md)。

### 推荐：使用 homelabctl

如需更丰富的 CLI 体验，建议使用 [homelabctl](https://github.com/xooooooooox/homelabctl)：

```shell
brew tap xooooooooox/radp
brew install homelabctl

homelabctl vf init myproject
homelabctl vg status
```

## 快速开始

### 1. 初始化项目

```shell
# 默认模板
radp-vf init myproject

# 指定模板
radp-vf init myproject --template k8s-cluster

# 带变量
radp-vf init myproject --template k8s-cluster \
  --set cluster_name=homelab \
  --set worker_count=3
```

### 2. 配置虚拟机

```yaml
# config/vagrant.yaml
radp:
  env: dev
  extend:
    vagrant:
      config:
        common:
          box:
            name: generic/ubuntu2204
```

```yaml
# config/vagrant-dev.yaml
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

### 3. 运行 Vagrant 命令

与标准 Vagrant 需要 `cd` 到 Vagrantfile 目录不同，radp-vf 可以从任意位置运行：

```shell
# 从项目目录运行
cd myproject
radp-vf vg status
radp-vf vg up

# 或使用 -c 参数从任意位置运行
radp-vf -c ~/myproject/config vg status
radp-vf -c ~/myproject/config vg up

# 或设置环境变量
export RADP_VAGRANT_CONFIG_DIR="$HOME/myproject/config"
radp-vf vg status
radp-vf vg ssh dev-my-cluster-node-1
radp-vf vg halt
radp-vf vg destroy
```

## 命令

| 命令              | 描述                  |
|-----------------|---------------------|
| `init [dir]`    | 从模板初始化项目            |
| `vg <cmd>`      | 运行 vagrant 命令       |
| `list`          | 列出集群和虚拟机            |
| `info`          | 显示环境信息              |
| `validate`      | 验证 YAML 配置          |
| `dump-config`   | 导出合并后的配置（JSON/YAML） |
| `generate`      | 生成独立 Vagrantfile    |
| `template list` | 列出可用模板              |
| `template show` | 显示模板详情              |

### 全局选项

| 选项                   | 描述                  |
|----------------------|---------------------|
| `-c, --config <dir>` | 配置目录（默认：`./config`） |
| `-e, --env <name>`   | 覆盖环境名称              |
| `-h, --help`         | 显示帮助                |
| `-v, --version`      | 显示版本                |

### 环境变量

| 变量                        | 描述     |
|---------------------------|--------|
| `RADP_VF_HOME`            | 框架安装目录 |
| `RADP_VAGRANT_CONFIG_DIR` | 配置目录路径 |
| `RADP_VAGRANT_ENV`        | 覆盖环境名称 |

## 配置概述

### 多文件加载

1. `vagrant.yaml` - 基础配置（必须包含 `radp.env`）
2. `vagrant-{env}.yaml` - 环境特定的集群配置

### 继承层级

设置继承顺序：**Global common → Cluster common → Guest**

| 配置项                      | 合并行为                                                                  |
|--------------------------|-----------------------------------------------------------------------|
| box, provider, network   | 深度合并（guest 覆盖）                                                        |
| provisions               | 按阶段合并：`global-pre → cluster-pre → guest → cluster-post → global-post` |
| triggers, synced-folders | 拼接                                                                    |

### 内置 Provisions

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"
```

可用：`radp:crypto/gpg-import`、`radp:nfs/external-nfs-mount`、`radp:ssh/host-trust`、`radp:ssh/cluster-trust`、`radp:time/chrony-sync`

### 内置 Triggers

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true
```

可用：`radp:system/disable-swap`、`radp:system/disable-selinux`、`radp:system/disable-firewalld`

## 文档

- [安装指南](docs/installation.md) - 完整安装选项、升级、Shell 补全
- [配置参考](docs/configuration-reference.md) - Box、provider、network、provisions、triggers、plugins
- [高级主题](docs/advanced.md) - 约定默认值、校验规则、扩展框架

## 贡献

开发设置和发布流程请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)
