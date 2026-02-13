# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

[![GitHub Release](https://img.shields.io/github/v/release/xooooooooox/radp-vagrant-framework?label=Release)](https://github.com/xooooooooox/radp-vagrant-framework/releases)
[![Copr build status](https://copr.fedorainfracloud.org/coprs/xooooooooox/radp/package/radp-vagrant-framework/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/xooooooooox/radp/package/radp-vagrant-framework/)
[![OBS package build status](https://build.opensuse.org/projects/home:xooooooooox:radp/packages/radp-vagrant-framework/badge.svg)](https://build.opensuse.org/package/show/home:xooooooooox:radp/radp-vagrant-framework)

[![CI: Check](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/ci.yml?label=CI)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/ci.yml)
[![CI: COPR](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/build-copr-package.yml?label=CI%3A%20COPR)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/build-copr-package.yml)
[![CI: OBS](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/build-obs-package.yml?label=CI%3A%20OBS)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/build-obs-package.yml)
[![CI: Homebrew](https://img.shields.io/github/actions/workflow/status/xooooooooox/radp-vagrant-framework/update-homebrew-tap.yml?label=Homebrew%20tap)](https://github.com/xooooooooox/radp-vagrant-framework/actions/workflows/update-homebrew-tap.yml)

[![COPR packages](https://img.shields.io/badge/COPR-packages-4b8bbe)](https://download.copr.fedorainfracloud.org/results/xooooooooox/radp/)
[![OBS packages](https://img.shields.io/badge/OBS-packages-4b8bbe)](https://software.opensuse.org//download.html?project=home%3Axooooooooox%3Aradp&package=radp-vagrant-framework)

基于 YAML 配置的多机 Vagrant 环境管理框架，支持配置继承和模块化配置脚本。

## 特性

- **声明式 YAML 配置** - 通过 YAML 定义虚拟机、网络、配置脚本和触发器
- **多文件配置** - 基础配置 + 环境特定覆盖（`vagrant.yaml` 或 `config.yaml` + `{base}-{env}.yaml`）
- **配置继承** - Global → Cluster → Guest 三级继承与自动合并
- **任意目录运行** - 无需 `cd` 到 Vagrantfile 目录，使用 `-c` 参数即可从任意位置运行
- **模板系统** - 通过预定义模板初始化项目（`base`、`single-node`、`k8s-cluster`）
- **内置 Provisions & Triggers** - 使用 `radp:` 前缀的可复用组件
- **插件支持** - vagrant-hostmanager、vagrant-vbguest、vagrant-proxyconf、vagrant-bindfs
- **约定优于配置** - 自动生成 hostname、provider name 和 group-id
- **调试支持** - 导出合并配置、生成独立 Vagrantfile 便于检查

## 前置条件

- Ruby 2.7+
- Vagrant 2.0+
- VirtualBox（或其他支持的 Provider）
- [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework)（必需，通过 Homebrew/包管理器自动安装）

## 安装

### Homebrew（推荐）

```shell
brew tap xooooooooox/radp
brew install radp-vagrant-framework
```

### 脚本安装

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh
| bash
```

从指定分支或标签安装：

```shell
bash install.sh --ref main
bash install.sh --ref v1.0.0-rc1
```

### 便携式二进制文件

从 [GitHub Releases](https://github.com/xooooooooox/radp-vagrant-framework/releases) 下载自包含的便携式二进制文件：

```shell
# macOS Apple Silicon
curl -fsSL https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-darwin-arm64 -o radp-vf
chmod +x radp-vf
./radp-vf --help

# Linux x86_64
curl -fsSL https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-linux-amd64 -o radp-vf
chmod +x radp-vf
./radp-vf --help
```

> **注意**：便携式二进制文件需要已安装 [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework)。

更多安装方式（手动安装、升级、Shell 补全）请参阅[安装指南](docs/installation.md)。

### 推荐：使用 homelabctl

如需更丰富的 CLI 体验，推荐使用 [homelabctl](https://github.com/xooooooooox/homelabctl)：

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

与标准 Vagrant 不同（需要 `cd` 到 Vagrantfile 目录），radp-vf 可从任意位置运行：

```shell
# 从项目目录运行
cd myproject
radp-vf vg status
radp-vf vg up

# 或使用 -c 选项从任意位置运行
radp-vf vg -c ~/myproject/config status
radp-vf vg -c ~/myproject/config up

# 或设置环境变量
export RADP_VAGRANT_CONFIG_DIR="$HOME/myproject/config"
radp-vf vg status
radp-vf vg ssh dev-my-cluster-node-1
radp-vf vg halt
radp-vf vg destroy
```

### 4. 按集群指定虚拟机

无需输入完整机器名，使用 `--cluster`（`-C`）按集群指定虚拟机：

```shell
# 启动集群中所有虚拟机
radp-vf vg up -C gitlab-runner

# 启动集群中指定虚拟机
radp-vf vg up -C gitlab-runner -G 1,2

# 多个集群
radp-vf vg up -C gitlab-runner,develop-centos9

# 原始语法仍然可用
radp-vf vg up homelab-gitlab-runner-1
```

Shell 补全支持集群名、虚拟机 ID 和机器名：

```bash
# 补全集群名
radp-vf vg -c /path/to/config --cluster <tab>

# 补全虚拟机 ID（需要 --cluster）
radp-vf vg -c /path/to/config --cluster develop --guest-ids <tab>

# 补全机器名（位置参数）
radp-vf vg -c /path/to/config status <tab>
```

补全的配置解析顺序：

1. `-c` / `--config` 命令行参数
2. `RADP_VAGRANT_CONFIG_DIR` 环境变量
3. `./config` 目录（如果存在）

## 命令

| 命令              | 说明                  |
|-----------------|---------------------|
| `init [dir]`    | 从模板初始化项目            |
| `vg <cmd>`      | 运行 Vagrant 命令       |
| `list`          | 列出集群和虚拟机            |
| `info`          | 显示环境信息              |
| `validate`      | 验证 YAML 配置          |
| `dump-config`   | 导出合并后的配置（JSON/YAML） |
| `generate`      | 生成独立 Vagrantfile    |
| `template list` | 列出可用模板              |
| `template show` | 显示模板详情              |

### 选项位置

```
radp-vf [框架选项] <命令> [命令选项] [参数]
```

**框架选项**（命令之前）：

| 选项           | 说明     |
|--------------|--------|
| `-v`         | 启用详细日志 |
| `--debug`    | 启用调试日志 |
| `-h, --help` | 显示帮助   |
| `--version`  | 显示版本   |

**命令选项**（命令之后，参数之前）：

| 选项                   | 说明                  |
|----------------------|---------------------|
| `-c, --config <dir>` | 配置目录（默认：`./config`） |
| `-e, --env <name>`   | 覆盖环境名               |
| `-h, --help`         | 显示命令帮助              |

**`vg` 命令特有选项：**

| 选项                      | 说明                           |
|-------------------------|------------------------------|
| `-C, --cluster <names>` | 集群名（多个用逗号分隔）                 |
| `-G, --guest-ids <ids>` | 虚拟机 ID（逗号分隔，需配合 `--cluster`） |

**示例：**

```shell
# 框架选项在命令之前
radp-vf -v list

# 命令选项在命令名之后
radp-vf list -c ./config -e prod
radp-vf vg -c ./config status
radp-vf dump-config -f yaml -o config.yaml

# 按集群指定虚拟机（vg 命令）
radp-vf vg status -C my-cluster
radp-vf vg up -C gitlab-runner -G 1,2
radp-vf vg halt -C cluster1,cluster2
```

### 环境变量

| 变量                                  | 说明                   |
|-------------------------------------|----------------------|
| `RADP_VF_HOME`                      | 框架安装目录               |
| `RADP_VAGRANT_CONFIG_DIR`           | 配置目录路径               |
| `RADP_VAGRANT_ENV`                  | 覆盖环境名                |
| `RADP_VAGRANT_CONFIG_BASE_FILENAME` | 覆盖基础配置文件名（支持任意自定义名称） |

## 配置概述

### 多文件加载

基础配置文件自动检测（或通过 `RADP_VAGRANT_CONFIG_BASE_FILENAME` 设置）：

1. `vagrant.yaml` 或 `config.yaml` - 基础配置（必须包含 `radp.env`）
2. `{base}-{env}.yaml` - 环境特定的集群配置（如 `vagrant-dev.yaml` 或 `config-dev.yaml`）

### 继承层级

配置继承：**Global common → Cluster common → Guest**

| 配置                       | 合并行为                                                                  |
|--------------------------|-----------------------------------------------------------------------|
| box, provider, network   | 深度合并（Guest 覆盖上层）                                                      |
| provisions               | 按阶段排序：`global-pre → cluster-pre → guest → cluster-post → global-post` |
| triggers, synced-folders | 串联追加                                                                  |

### 内置 Provisions

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"
```

可用：`radp:crypto/gpg-import`、`radp:crypto/gpg-preset-passphrase`、`radp:git/clone`、
`radp:nfs/external-nfs-mount`、`radp:ssh/host-trust`、`radp:ssh/cluster-trust`、`radp:time/chrony-sync`、
`radp:yadm/clone`

### 内置 Triggers

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true
```

可用：`radp:system/disable-swap`、`radp:system/disable-selinux`、`radp:system/disable-firewalld`

### 用户自定义 Provisions & Triggers

使用 `user:` 前缀在项目中定义可复用组件：

```
myproject/
└── config/
    ├── provisions/
    │   ├── definitions/
    │   │   └── docker/setup.yaml    # -> user:docker/setup
    │   └── scripts/
    │       └── docker/setup.sh
    └── triggers/
        ├── definitions/
        │   └── system/cleanup.yaml  # -> user:system/cleanup
        └── scripts/
            └── system/cleanup.sh
```

使用：

```yaml
provisions:
  - name: user:docker/setup
    enabled: true

triggers:
  - name: user:system/cleanup
    enabled: true
```

### 用户模板

在 `~/.config/radp-vagrant/templates/` 中创建自定义模板：

```
~/.config/radp-vagrant/templates/
└── my-template/
    ├── template.yaml              # 元数据和变量
    └── files/                     # 要复制的文件
        ├── config/
        │   ├── vagrant.yaml
        │   └── vagrant-{{env}}.yaml
        ├── provisions/
        └── triggers/
```

详情请参阅[模板指南](docs/user-guide/templates.md)。

## 文档

- [快速开始](docs/getting-started.md) - 入门指南
- [安装指南](docs/installation.md) - 完整安装选项、升级、Shell 补全
- [配置参考](docs/configuration.md) - Box、Provider、网络、Provisions、Triggers、插件
- [用户指南](docs/user-guide/) - Provisions、Triggers、插件、模板
- [开发者指南](docs/developer/) - 架构、扩展框架
- [CLI 参考](docs/reference/cli-reference.md) - 完整 CLI 命令参考

## 相关项目

- [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework) - Bash 工程化 & CLI 框架（依赖）
- [homelabctl](https://github.com/xooooooooox/homelabctl) - Homelab 基础设施 CLI（使用本框架）

## 贡献

请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解开发设置和发版流程。

## 许可证

[MIT](LICENSE)
