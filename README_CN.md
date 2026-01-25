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

基于 YAML 配置的多机 Vagrant 环境管理框架。

## 特性

- **声明式 YAML 配置**: 通过 YAML 定义虚拟机、网络、配置脚本和触发器
- **多文件配置**: 基础配置 + 环境特定覆盖 (`vagrant.yaml` + `vagrant-{env}.yaml`)
- **配置继承**: Global → Cluster → Guest 三级继承，自动合并
- **数组连接**: provisions、triggers、synced-folders 在继承时累加而非覆盖
- **模块化插件系统**: 每个插件配置器独立文件，便于维护
- **约定优于配置**: 自动生成 hostname、provider name 和 group-id
- **Dry-Run 预览**: 生成独立 Vagrantfile 以检查最终配置
- **配置校验**: 检测重复的集群名称和 guest ID
- **调试支持**: 可导出最终合并后的配置（JSON/YAML）

## 快速开始

### 安装

前置要求:

- Ruby 2.7+
- Vagrant 2.0+
- VirtualBox（或其他支持的 provider）

#### 脚本安装 (curl / wget / fetch)

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh
| bash
```

或:

```shell
wget -qO- https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh
| bash
```

可选环境变量:

```shell
RADP_VF_VERSION=vX.Y.Z \
  RADP_VF_REF=main \
  RADP_VF_INSTALL_DIR="$HOME/.local/lib/radp-vagrant-framework" \
  RADP_VF_BIN_DIR="$HOME/.local/bin" \
  RADP_VF_ALLOW_ANY_DIR=1 \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh)"
```

`RADP_VF_REF` 可以是分支、标签或提交，优先级高于 `RADP_VF_VERSION`。
如果自定义安装目录不以 `radp-vagrant-framework` 结尾，需设置 `RADP_VF_ALLOW_ANY_DIR=1`。
默认路径：`~/.local/lib/radp-vagrant-framework` 和 `~/.local/bin`。

重新运行脚本即可升级。

#### Homebrew (macOS/Linux)

点击 [这里](https://github.com/xooooooooox/homebrew-radp/blob/main/Formula/radp-vagrant-framework.rb) 查看详情。

```shell
brew tap xooooooooox/radp
brew install radp-vagrant-framework
```

#### 手动安装 (Git clone / Release 下载)

预构建的发布包可在每个 Release 页面下载：<https://github.com/xooooooooox/radp-vagrant-framework/releases/latest>

或克隆仓库：

```shell
git clone https://github.com/xooooooooox/radp-vagrant-framework.git
cd radp-vagrant-framework/src/main/ruby
```

### 升级

#### 脚本

重新运行安装脚本即可升级到最新版本。

#### Homebrew

```shell
brew upgrade radp-vagrant-framework
```

#### 手动

从最新 Release 下载新的发布包并解压，或使用 `git pull` 更新克隆的仓库。

### Shell 补全

Bash:

```shell
# 复制补全脚本
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/completions/radp-vf.bash \
  >~/.local/share/bash-completion/completions/radp-vf

# 或在 ~/.bashrc 中直接 source
echo 'source ~/.local/share/bash-completion/completions/radp-vf' >>~/.bashrc
```

Zsh:

```shell
# 创建 zfunc 目录（如不存在）
mkdir -p ~/.zfunc

# 复制补全脚本
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/completions/radp-vf.zsh \
  >~/.zfunc/_radp-vf

# 添加到 ~/.zshrc（在 compinit 之前）
echo 'fpath=(~/.zfunc $fpath)' >>~/.zshrc
```

### 推荐：使用 homelabctl

如需更丰富的 CLI 体验和统一的 homelab 管理，建议使用
[homelabctl](https://github.com/xooooooooox/homelabctl)，它封装了 radp-vagrant-framework 并提供：

- 开箱即用的 Shell 补全
- 统一的命令结构
- 更多 homelab 管理功能

```shell
# 安装 homelabctl
brew tap xooooooooox/radp
brew install homelabctl

# 使用 homelabctl 代替 radp-vf
homelabctl vf init myproject
homelabctl vg status
homelabctl vg up
```

## 如何使用

### 初始化新项目

安装后，使用以下命令创建带有示例配置的新项目：

```shell
# 使用默认模板（base）初始化
radp-vf init myproject

# 使用指定模板初始化
radp-vf init myproject --template k8s-cluster

# 使用模板变量初始化
radp-vf init myproject --template k8s-cluster \
  --set cluster_name=homelab \
  --set worker_count=3
```

这会创建以下目录结构：

```
myproject/
└── config/
    ├── vagrant.yaml          # 基础配置（设置 env）
    ├── vagrant-sample.yaml   # 环境特定集群配置
    └── provisions/           # 用户自定义 provisions
        ├── definitions/
        │   └── example.yaml  # 示例 provision 定义
        └── scripts/
            └── example.sh    # 示例 provision 脚本
```

框架的 Vagrantfile 会通过 `radp-vf vg` 自动使用 - 项目目录中无需创建 Vagrantfile。

### 可用模板

框架提供了常用场景的内置模板：

| 模板            | 描述                                      |
|---------------|-----------------------------------------|
| `base`        | 入门级最小模板（默认）                             |
| `single-node` | 增强型单节点虚拟机，预配置常用 provisions              |
| `k8s-cluster` | 多节点 Kubernetes 集群，包含 master 和 worker 节点 |

```shell
# 列出可用模板
radp-vf template list

# 查看模板详情和变量
radp-vf template show k8s-cluster
```

### 配置文件

框架使用双文件配置方式：

1. **`config/vagrant.yaml`** - 基础配置（必需）
    - 必须包含 `radp.env` 来指定环境
    - 定义全局设置、插件和公共配置

2. **`config/vagrant-{env}.yaml`** - 环境特定集群配置
    - `{env}` 对应基础配置中 `radp.env` 的值
    - 定义该环境的集群和虚拟机

最小配置示例：

```yaml
# config/vagrant.yaml
radp:
  env: dev    # 将加载 config/vagrant-dev.yaml
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

### 环境变量

| 变量                        | 说明                | 默认值                          |
|---------------------------|-------------------|------------------------------|
| `RADP_VF_HOME`            | 框架安装目录            | 从脚本位置自动检测                    |
| `RADP_VAGRANT_CONFIG_DIR` | 配置目录路径（`vg` 命令必需） | 当前目录下的 `./config`（如存在）       |
| `RADP_VAGRANT_ENV`        | 覆盖环境名称            | `vagrant.yaml` 中的 `radp.env` |

**RADP_VF_HOME 默认值：**

- 脚本安装：`~/.local/lib/radp-vagrant-framework`
- Homebrew 安装：`/opt/homebrew/Cellar/radp-vagrant-framework/<version>/libexec`
- Git clone：`<repo>`（项目根目录，自动检测）

**优先级（从高到低）：**

```
-c 参数 > RADP_VAGRANT_CONFIG_DIR > ./config
-e 参数 > RADP_VAGRANT_ENV > vagrant.yaml 中的 radp.env
```

### 全局选项

| 选项                   | 说明                  |
|----------------------|---------------------|
| `-c, --config <dir>` | 配置目录（默认：`./config`） |
| `-e, --env <name>`   | 覆盖环境名称              |
| `-h, --help`         | 显示帮助                |
| `-v, --version`      | 显示版本                |

### 运行 Vagrant 命令

使用 `radp-vf vg` 运行 vagrant 命令。可以在项目目录中运行，也可以使用 `-c` 参数或 `RADP_VAGRANT_CONFIG_DIR` 从任意目录运行：

```shell
# 从项目目录运行（包含 config/vagrant.yaml）
cd myproject
radp-vf vg status
radp-vf vg up
radp-vf vg ssh sample-example-node-1
radp-vf vg halt
radp-vf vg destroy

# 使用 -c 参数指定配置目录
radp-vf -c /path/to/project/config vg status
radp-vf -c ~/myproject/config vg up

# 或者设置环境变量
export RADP_VAGRANT_CONFIG_DIR="$HOME/myproject/config"
radp-vf vg status

# 使用 -e 参数切换环境
radp-vf -e dev vg status # 使用 vagrant-dev.yaml
radp-vf -e prod vg up # 使用 vagrant-prod.yaml

# 组合 -c 和 -e 参数
radp-vf -c ~/myproject/config -e prod vg up
```

**注意：** 原生 `vagrant` 命令与 `radp-vf vg` 相互隔离。在包含自己 Vagrantfile 的目录中运行 `vagrant up` 不会受 RADP
Vagrant Framework 影响。

**推荐：为远程配置目录设置 `VAGRANT_DOTFILE_PATH`**

当使用 `RADP_VAGRANT_CONFIG_DIR` 从任意目录运行命令时，Vagrant 默认会在当前工作目录创建 `.vagrant` 目录来存储机器状态。这可能导致以下问题：

- 机器状态分散在不同目录中
- 从不同路径运行时出现 "This machine used to live in..." 警告

为避免这些问题，建议将 `VAGRANT_DOTFILE_PATH` 设置为固定位置：

```shell
# 添加到 ~/.bashrc 或 ~/.zshrc
export RADP_VAGRANT_CONFIG_DIR="$HOME/.config/radp-vagrant"
export VAGRANT_DOTFILE_PATH="$HOME/.config/radp-vagrant/.vagrant"
```

这可以确保 Vagrant 始终使用同一个 `.vagrant` 目录，无论你从哪里运行命令。

### CLI 命令

```shell
# 模板管理
radp-vf template list
radp-vf template show k8s-cluster

# 显示环境信息
radp-vf info

# 列出集群和虚拟机
radp-vf list
radp-vf -e prod list

# 详细模式（显示所有配置项）
radp-vf list -v
radp-vf list -v node-1

# 按类型过滤
radp-vf list --provisions
radp-vf list --synced-folders
radp-vf list --triggers node-1

# 验证 YAML 配置
radp-vf validate

# 导出合并后的配置（默认 JSON）
radp-vf dump-config

# 导出为 YAML 格式
radp-vf dump-config -f yaml

# 按 guest ID 或 machine name 过滤
radp-vf dump-config node-1

# 导出到文件（使用 -o 选项）
radp-vf dump-config -o config.json
radp-vf dump-config -f yaml -o config.yaml

# 或使用重定向
radp-vf dump-config -f yaml >config.yaml

# 生成独立 Vagrantfile（dry-run 预览）
radp-vf generate

# 保存生成的 Vagrantfile
radp-vf generate Vagrantfile.preview
```

### 从 Git Clone 使用（开发模式）

用于框架开发或直接从源码使用：

```bash
cd radp-vagrant-framework/src/main/ruby

# 验证配置
vagrant validate

# 查看虚拟机状态
vagrant status

# 调试：导出合并后的配置
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"

# 输出为 YAML 格式
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', nil, format: :yaml)"

# 生成独立 Vagrantfile
ruby -r ./lib/radp_vagrant -e "puts RadpVagrant.generate_vagrantfile('config')"
```

## 目录结构

```
bin/
└── radp-vf                         # CLI 入口
completions/
├── radp-vf.bash                    # Bash 补全
└── radp-vf.zsh                     # Zsh 补全
install.sh                          # 安装脚本
templates/                          # 内置项目模板
├── base/                           # 入门级最小模板
│   ├── template.yaml               # 模板元数据
│   └── files/                      # 模板文件
├── single-node/                    # 增强型单节点模板
└── k8s-cluster/                    # Kubernetes 集群模板
src/main/ruby/
├── Vagrantfile                     # Vagrant 入口文件
├── config/
│   ├── vagrant.yaml                # 基础配置（设置 env）
│   ├── vagrant-sample.yaml         # Sample 环境集群
│   └── vagrant-local.yaml          # Local 环境集群
└── lib/
    ├── radp_vagrant.rb             # 主协调器
    └── radp_vagrant/
        ├── config_loader.rb        # 多文件 YAML 加载
        ├── config_merger.rb        # 深度合并（数组连接）
        ├── generator.rb            # Vagrantfile 生成器（dry-run）
        ├── path_resolver.rb        # 统一的两级路径解析
        ├── configurators/
        │   ├── box.rb              # Box 配置
        │   ├── provider.rb         # Provider 配置（VirtualBox 等）
        │   ├── network.rb          # 网络和主机名
        │   ├── hostmanager.rb      # Guest 级别 hostmanager
        │   ├── synced_folder.rb    # 同步文件夹
        │   ├── provision.rb        # 配置脚本
        │   ├── trigger.rb          # 触发器
        │   ├── plugin.rb           # 插件协调器
        │   └── plugins/            # 模块化插件配置器
        │       ├── base.rb         # 基类
        │       ├── registry.rb     # 插件注册表
        │       ├── hostmanager.rb  # vagrant-hostmanager
        │       ├── vbguest.rb      # vagrant-vbguest
        │       ├── proxyconf.rb    # vagrant-proxyconf
        │       └── bindfs.rb       # vagrant-bindfs
        ├── provisions/             # 内置 & 用户 provisions
        │   ├── registry.rb         # 内置 provision 注册表 (radp:)
        │   ├── user_registry.rb    # 用户 provision 注册表 (user:)
        │   ├── definitions/        # Provision 定义文件 (YAML)
        │   │   ├── nfs/
        │   │   │   └── external-nfs-mount.yaml
        │   │   ├── ssh/
        │   │   │   ├── host-trust.yaml
        │   │   │   └── cluster-trust.yaml
        │   │   └── time/
        │   │       └── chrony-sync.yaml
        │   └── scripts/            # Provision 脚本
        │       ├── nfs/
        │       │   └── external-nfs-mount.sh
        │       ├── ssh/
        │       │   ├── host-trust.sh
        │       │   └── cluster-trust.sh
        │       └── time/
        │           └── chrony-sync.sh
        └── triggers/               # 内置触发器
            ├── registry.rb         # 内置触发器注册表 (radp:)
            ├── definitions/        # 触发器定义文件 (YAML)
            │   └── system/
            │       ├── disable-swap.yaml
            │       ├── disable-selinux.yaml
            │       └── disable-firewalld.yaml
            └── scripts/            # 触发器脚本
                └── system/
                    ├── disable-swap.sh
                    ├── disable-selinux.sh
                    └── disable-firewalld.sh
```

## 配置结构

### 多文件加载

配置按顺序加载并深度合并：

1. `vagrant.yaml` - 基础配置（必须包含 `radp.env`）
2. `vagrant-{env}.yaml` - 环境特定集群配置

```yaml
# vagrant.yaml - 基础配置
radp:
  env: dev  # 决定加载哪个环境文件
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
          # 被所有 guest 继承的全局配置
          provisions:
            - name: global-init
              enabled: true
              type: shell
              run: once
              inline: echo "Hello"

# vagrant-dev.yaml - Dev 环境
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

## 配置参考

### 插件 (plugins)

插件在 `plugins` 数组中配置。每个插件可以指定：

- `name`：插件名称（必填）
- `required`：缺失时自动安装（默认：false）
- `options`：插件特定配置选项

支持的插件：

- `vagrant-hostmanager` - 主机文件管理
- `vagrant-vbguest` - VirtualBox Guest Additions
- `vagrant-proxyconf` - 代理配置
- `vagrant-bindfs` - 绑定挂载（按 synced-folder 配置）

#### vagrant-hostmanager

管理宿主机和虚拟机上的 `/etc/hosts` 文件，用于主机名解析。

**基本配置（自动模式）：**

```yaml
plugins:
  - name: vagrant-hostmanager
    required: true
    options:
      enabled: true               # vagrant up/destroy 时更新 hosts
      manage_host: true           # 更新宿主机的 /etc/hosts
      manage_guest: true          # 更新虚拟机的 /etc/hosts
      include_offline: false      # 将离线 VM 包含在 hosts 文件中
```

**Provisioner 模式：**

使用 `provisioner: enabled` 将 hostmanager 作为 provisioner 运行，而不是自动运行。这可以控制 hosts 文件的更新时机：

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled        # 作为 provisioner 运行（与 enabled 互斥）
      manage_host: true
      manage_guest: true
```

> 注意：`provisioner` 和 `enabled` 是互斥的。如果两者都设置，框架会自动禁用 `enabled` 并输出警告日志。

**自定义 IP 解析器：**

默认情况下，hostmanager 使用 `vm.ssh_info[:host]`，对于 NAT 网络可能返回 `127.0.0.1`。使用 `ip_resolver` 从虚拟机提取正确的
IP：

```yaml
plugins:
  - name: vagrant-hostmanager
    options:
      provisioner: enabled
      manage_host: true
      ip_resolver:
        enabled: true
        execute: "hostname -I"    # 在 guest 上执行的命令
        regex: "^(\\S+)"          # 提取 IP 的正则表达式（使用第一个捕获组）
```

**执行时机：**

当 `provisioner: enabled` 时，hostmanager 在**所有其他 provisions 之后**运行：

```
global-pre → cluster-pre → guest → cluster-post → global-post → hostmanager
```

**在运行中的 VM 上触发：**

```bash
# 仅触发 hostmanager（跳过其他 provisions）
radp-vf vg provision --provision-with hostmanager

# 运行所有 provisioners（包括 hostmanager）
radp-vf vg provision
```

#### vagrant-vbguest

自动在虚拟机上安装和更新 VirtualBox Guest Additions。

##### 推荐配置

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      auto_update: true           # 启动时检查/更新（默认: true）
      auto_reboot: true           # 安装后需要时自动重启
```

##### 不同发行版配置

<details>
<summary><b>Ubuntu / Debian</b></summary>

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      installer: ubuntu           # 或 debian
      auto_update: true
      auto_reboot: true
```

</details>

<details>
<summary><b>CentOS / RHEL / Rocky Linux</b></summary>

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      installer: centos
      auto_update: true
      auto_reboot: true
      installer_options:
        allow_kernel_upgrade: true    # 需要时允许内核升级
        reboot_timeout: 300           # 内核升级后等待时间（秒）
```

> 注意：CentOS 在 Guest Additions 版本不匹配时可能需要内核升级。设置 `allow_kernel_upgrade: true` 允许此操作。

</details>

<details>
<summary><b>Fedora</b></summary>

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      installer: fedora
      auto_update: true
      auto_reboot: true
```

</details>

##### 常用场景

| 场景     | 配置                                             |
|--------|------------------------------------------------|
| 禁用自动更新 | `auto_update: false`                           |
| 仅检查不安装 | `no_install: true`                             |
| 离线环境   | `no_remote: true` + `iso_path: "/path/to/iso"` |
| 允许降级   | `allow_downgrade: true`（默认）                    |

**离线 / 内网环境：**

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      no_remote: true
      iso_path: "/shared/VBoxGuestAdditions.iso"
      iso_upload_path: "/tmp"
      iso_mount_point: "/mnt"
```

**完全禁用（使用 box 内置的 Guest Additions）：**

```yaml
plugins:
  - name: vagrant-vbguest
    options:
      auto_update: false
      no_install: true
```

<details>
<summary><b>所有可用选项</b></summary>

| 选项                    | 类型      | 默认值           | 说明                                                  |
|-----------------------|---------|---------------|-----------------------------------------------------|
| `auto_update`         | boolean | `true`        | 启动时检查/更新 Guest Additions                            |
| `no_remote`           | boolean | `false`       | 禁止从远程下载 ISO                                         |
| `no_install`          | boolean | `false`       | 仅检查版本，不安装                                           |
| `auto_reboot`         | boolean | `true`        | 安装后需要时自动重启                                          |
| `allow_downgrade`     | boolean | `true`        | 允许安装旧版本                                             |
| `iso_path`            | string  | -             | 自定义 ISO 路径（本地或带 `%{version}` 的 URL）                 |
| `iso_upload_path`     | string  | `/tmp`        | 虚拟机中存放 ISO 的目录                                      |
| `iso_mount_point`     | string  | `/mnt`        | 虚拟机中的挂载点                                            |
| `installer`           | string  | auto          | 安装器类型：`linux`、`ubuntu`、`debian`、`centos`、`fedora` 等 |
| `installer_arguments` | array   | `["--nox11"]` | 传递给安装器的参数                                           |
| `yes`                 | boolean | `true`        | 自动回答 yes                                            |
| `installer_options`   | hash    | -             | 发行版特定选项                                             |
| `installer_hooks`     | hash    | -             | 钩子：`before_install`、`after_install` 等               |

</details>

#### vagrant-bindfs

通过 bindfs 挂载重新映射用户/组所有权，解决 NFS 权限问题。

##### 为什么使用 bindfs？

NFS 共享会继承宿主机的数字用户/组 ID（例如 macOS 用户在虚拟机内显示为 `501:20`）。这会导致虚拟机用户（通常是
`vagrant:vagrant`）无法访问挂载的文件。vagrant-bindfs 通过重新挂载 NFS 共享并修正所有权来解决此问题。

##### 推荐配置

在 `synced-folders` 中为 NFS 文件夹配置 bindfs：

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

这将：

1. 将 NFS 挂载到 `/mnt-bindfs/data`（临时路径）
2. 使用 bindfs 重新挂载到 `/data`，所有权为 `vagrant:vagrant`

##### 带权限映射

```yaml
synced-folders:
  nfs:
    - host: ./app
      guest: /var/www/app
      bindfs:
        enabled: true
        force_user: www-data
        force_group: www-data
        perms: "u=rwX:g=rX:o=rX"         # 用户 rwx，组/其他 rx
        create_with_perms: "u=rwX:g=rX:o=rX"
```

##### 全局插件选项

```yaml
plugins:
  - name: vagrant-bindfs
    options:
      debug: false                       # 启用调试输出
      force_empty_mountpoints: true      # 挂载前清理挂载点
      skip_validations: # 跳过用户/组存在性检查
        - user
        - group
      default_options: # 所有 bind_folder 调用的默认选项
        force_user: vagrant
        force_group: vagrant
```

<details>
<summary><b>所有 bindfs 选项（按文件夹）</b></summary>

| 选项                  | 类型      | 说明                                     |
|---------------------|---------|----------------------------------------|
| `enabled`           | boolean | 为此文件夹启用 bindfs                         |
| `force_user`        | string  | 强制所有文件归此用户所有                           |
| `force_group`       | string  | 强制所有文件归此组所有                            |
| `perms`             | string  | 权限映射（如 `u=rwX:g=rD:o=rD`）              |
| `create_with_perms` | string  | 新建文件的权限                                |
| `create_as_user`    | boolean | 以访问用户身份创建文件                            |
| `chown_ignore`      | boolean | 忽略 chown 操作                            |
| `chgrp_ignore`      | boolean | 忽略 chgrp 操作                            |
| `o`                 | string  | 附加挂载选项                                 |
| `after`             | string  | 何时绑定：`synced_folders`（默认）或 `provision` |

</details>

<details>
<summary><b>所有全局插件选项</b></summary>

| 选项                           | 类型      | 默认值     | 说明                     |
|------------------------------|---------|---------|------------------------|
| `debug`                      | boolean | `false` | 启用详细输出                 |
| `force_empty_mountpoints`    | boolean | `false` | 绑定前清理挂载目标              |
| `skip_validations`           | array   | `[]`    | 跳过验证：`user`、`group`    |
| `bindfs_version`             | string  | -       | 指定安装的 bindfs 版本        |
| `install_bindfs_from_source` | boolean | `false` | 从源码构建 bindfs           |
| `default_options`            | hash    | -       | 所有 bind_folder 调用的默认选项 |

</details>

### Box

```yaml
box:
  name: generic/centos9s          # Box 名称
  version: 4.3.12                 # Box 版本
  check-update: false             # 禁用更新检查
```

### Provider

```yaml
provider:
  type: virtualbox                # Provider 类型
  name: my-vm                     # 虚拟机名称（默认: {env}-{cluster}-{guest-id}）
  group-id: my-group              # VirtualBox 分组（默认: {env}/{cluster}）
  mem: 2048                       # 内存（MB）
  cpus: 2                         # CPU 数量
  gui: false                      # 显示 GUI
  customize: # VirtualBox 自定义命令
    - [ 'modifyvm', ':id', '--nictype1', 'virtio' ]
```

<details>
<summary><b>所有 provider 选项 (VirtualBox)</b></summary>

| 选项          | 类型      | 默认值                          | 说明                             |
|-------------|---------|------------------------------|--------------------------------|
| `type`      | string  | `virtualbox`                 | Provider 类型                    |
| `name`      | string  | `{env}-{cluster}-{guest-id}` | 虚拟机名称（用作 Vagrant machine name） |
| `group-id`  | string  | `{env}/{cluster}`            | VirtualBox 分组（用于组织虚拟机）         |
| `mem`       | number  | `2048`                       | 内存（MB）                         |
| `cpus`      | number  | `2`                          | CPU 数量                         |
| `gui`       | boolean | `false`                      | 显示 VirtualBox GUI              |
| `customize` | array   | -                            | VirtualBox 自定义命令（modifyvm 等）   |

</details>

### 网络 (network)

```yaml
# 主机名在 guest 级别（默认: {guest-id}.{cluster}.{env}）
hostname: node.local

network:
  private-network:
    enabled: true
    type: dhcp                    # dhcp 或 static
    ip: 172.16.10.100             # static 类型时使用（单个 IP）
    netmask: 255.255.255.0
  public-network:
    enabled: true
    type: static
    ip: # 支持多个 IP（创建多个网络接口）
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

<details>
<summary><b>所有网络选项</b></summary>

**主机名：**

| 选项         | 类型     | 默认值                          | 说明                 |
|------------|--------|------------------------------|--------------------|
| `hostname` | string | `{guest-id}.{cluster}.{env}` | 虚拟机主机名（guest 级别配置） |

**私有网络 (private-network)：**

| 选项            | 类型           | 默认值      | 说明                       |
|---------------|--------------|----------|--------------------------|
| `enabled`     | boolean      | -        | 启用私有网络                   |
| `type`        | string       | `static` | 网络类型：`dhcp` 或 `static`   |
| `ip`          | string/array | -        | 静态 IP 地址；多个 IP 会创建多个网络接口 |
| `netmask`     | string       | -        | 子网掩码（如 `255.255.255.0`）  |
| `auto-config` | boolean      | `true`   | 自动配置网络接口                 |

**公有网络 (public-network)：**

| 选项                                | 类型           | 默认值      | 说明                       |
|-----------------------------------|--------------|----------|--------------------------|
| `enabled`                         | boolean      | -        | 启用公有网络                   |
| `type`                            | string       | `static` | 网络类型：`dhcp` 或 `static`   |
| `ip`                              | string/array | -        | 静态 IP 地址；多个 IP 会创建多个网络接口 |
| `netmask`                         | string       | -        | 子网掩码                     |
| `bridge`                          | string/array | -        | 宿主机桥接网卡                  |
| `auto-config`                     | boolean      | `true`   | 自动配置网络接口                 |
| `use-dhcp-assigned-default-route` | boolean      | `false`  | 使用 DHCP 分配的默认路由          |

**端口转发 (forwarded-ports)：**

| 选项             | 类型      | 默认值     | 说明               |
|----------------|---------|---------|------------------|
| `enabled`      | boolean | -       | 启用此端口转发          |
| `guest`        | number  | -       | 虚拟机端口（必填）        |
| `host`         | number  | -       | 宿主机端口（必填）        |
| `protocol`     | string  | `tcp`   | 协议：`tcp` 或 `udp` |
| `id`           | string  | -       | 端口转发的唯一标识符       |
| `auto-correct` | boolean | `false` | 端口冲突时自动修正宿主机端口   |

</details>

### Hostmanager（Guest 级别）

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

### 同步文件夹 (synced-folders)

```yaml
synced-folders:
  basic:
    - enabled: true
      host: ./data                # 主机路径
      guest: /data                # 虚拟机挂载路径
      create: true                # 不存在时创建
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

### 配置脚本 (provisions)

```yaml
provisions:
  - name: setup                   # 名称
    desc: '配置脚本描述'            # 描述
    enabled: true
    type: shell                   # shell 或 file
    privileged: true              # 是否以 root 运行（默认: false）
    run: once                     # once, always, never
    phase: pre                    # pre（默认）或 post - 仅用于 common provisions
    inline: |                     # 内联脚本
      echo "Hello $MY_VAR"
    env: # 环境变量
      MY_VAR: "world"
    # 或使用文件路径:
    # path: ./scripts/setup.sh
    # args: arg1 arg2
    # before: other-provision     # 在某脚本之前运行（脚本必须存在）
    # after: other-provision      # 在某脚本之后运行
```

**使用外部脚本和环境变量：**

```yaml
provisions:
  - name: mount-nfs
    enabled: true
    type: shell
    privileged: true
    run: always
    path: scripts/mount-nfs.sh
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume2/nfs"
```

**脚本路径解析：**

`path` 选项支持绝对路径和相对路径。相对路径使用智能检测：

1. 首先检查路径是否存在于 **config 目录内**
2. 如果不存在，检查路径是否存在于 **项目根目录**（config 目录的父目录）
3. 如果都不存在，使用 config 相对路径（Vagrant 会报告错误）

这同时支持标准项目结构和自定义 `RADP_VAGRANT_CONFIG_DIR` 设置。

| 路径类型 | 示例                      | 解析顺序                                                                       |
|------|-------------------------|----------------------------------------------------------------------------|
| 绝对路径 | `/opt/scripts/setup.sh` | 直接使用                                                                       |
| 相对路径 | `scripts/setup.sh`      | 1. `{config_dir}/scripts/setup.sh`<br>2. `{project_root}/scripts/setup.sh` |

**支持的目录结构：**

```
# 结构 A：标准项目 (radp-vf init)
myproject/                          # 项目根目录
├── config/                         # RADP_VAGRANT_CONFIG_DIR
│   ├── vagrant.yaml
│   └── vagrant-{env}.yaml
└── scripts/                        # path: scripts/setup.sh ✓
    └── setup.sh

# 结构 B：自定义配置目录
~/.config/radp-vagrant/             # RADP_VAGRANT_CONFIG_DIR
├── vagrant.yaml
├── vagrant-{env}.yaml
└── scripts/                        # path: scripts/setup.sh ✓
    └── setup.sh
```

两种结构都可以使用 `path: scripts/setup.sh`。

**phase 字段（仅用于 common provisions）：**

`phase` 字段控制 common provisions 相对于 guest provisions 的执行时机：

- `pre`（默认）：在 guest provisions 之前运行
- `post`：在 guest provisions 之后运行

```yaml
# vagrant.yaml - global common
common:
  provisions:
    - name: global-init
      phase: pre                  # 最先运行（默认）
      inline: echo "1. Global init"
    - name: global-cleanup
      phase: post                 # 最后运行
      inline: echo "5. Global cleanup"

# vagrant-dev.yaml - cluster common
clusters:
  - name: my-cluster
    common:
      provisions:
        - name: cluster-init
          phase: pre
          inline: echo "2. Cluster init"
        - name: cluster-cleanup
          phase: post
          inline: echo "4. Cluster cleanup"
    guests:
      - id: node-1
        provisions:
          - name: guest-setup     # Guest provisions 在中间运行
            inline: echo "3. Guest setup"
```

执行顺序：`global-pre → cluster-pre → guest → cluster-post → global-post`

#### 内置 Provisions

框架提供了用于常见任务的内置 provisions。内置 provisions 以 `radp:` 前缀标识，并带有合理的默认配置。

**可用的内置 provisions：**

| 名称                            | 描述                     | 默认值                             |
|-------------------------------|------------------------|---------------------------------|
| `radp:nfs/external-nfs-mount` | 挂载外部 NFS 共享并自动创建目录和验证  | `privileged: true, run: always` |
| `radp:ssh/host-trust`         | 添加宿主机 SSH 公钥到虚拟机实现免密登录 | `privileged: false, run: once`  |
| `radp:ssh/cluster-trust`      | 配置同一集群内虚拟机之间的 SSH 互信   | `privileged: true, run: once`   |
| `radp:time/chrony-sync`       | 使用 chrony 配置 NTP 时间同步  | `privileged: true, run: once`   |

**使用方法：**

```yaml
provisions:
  # NFS 挂载
  - name: radp:nfs/external-nfs-mount
    enabled: true
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"

  # SSH 宿主机信任（宿主机 -> 虚拟机）
  - name: radp:ssh/host-trust
    enabled: true
    env:
      HOST_SSH_PUBLIC_KEY_FILE: "/vagrant/host_ssh_key.pub"

  # SSH 集群互信（虚拟机 <-> 虚拟机，仅同用户互信，通常在 cluster.common 级别配置）
  # 密钥文件: {dir}/id_{env}_{cluster}_{user} 和 {dir}/id_{env}_{cluster}_{user}.pub
  # 示例（env 为 "dev"，cluster 为 "hadoop"）: /vagrant/keys/id_dev_hadoop_vagrant[.pub]
  - name: radp:ssh/cluster-trust
    enabled: true
    env:
      CLUSTER_SSH_KEY_DIR: "/vagrant/keys"
      SSH_USERS: "vagrant,root"

  # 使用 chrony 进行时间同步
  - name: radp:time/chrony-sync
    enabled: true
    env:
      NTP_SERVERS: "ntp.aliyun.com,ntp1.aliyun.com"  # 可选
      TIMEZONE: "Asia/Shanghai"                       # 可选
```

**覆盖默认值：**

用户配置优先于内置默认值：

```yaml
provisions:
  - name: radp:nfs/external-nfs-mount
    enabled: true
    run: once            # 覆盖默认值 (always -> once)
    privileged: false    # 覆盖默认值 (true -> false)
    env:
      NFS_SERVER: "nas.example.com"
      NFS_ROOT: "/volume1/nfs"
```

**环境变量：**

内置 provisions 在其 YAML 定义中声明必需和可选的环境变量。可选变量会自动应用默认值。

| Provision                     | 必需变量                     | 可选变量（默认值）                                                               |
|-------------------------------|--------------------------|-------------------------------------------------------------------------|
| `radp:nfs/external-nfs-mount` | `NFS_SERVER`, `NFS_ROOT` | 无                                                                       |
| `radp:ssh/host-trust`         | 无（需提供以下之一）               | `HOST_SSH_PUBLIC_KEY`, `HOST_SSH_PUBLIC_KEY_FILE`, `SSH_USERS`(vagrant) |
| `radp:ssh/cluster-trust`      | `CLUSTER_SSH_KEY_DIR`    | `SSH_USERS`(vagrant), `TRUSTED_HOST_PATTERN`(自动)                        |
| `radp:time/chrony-sync`       | 无                        | `NTP_SERVERS`, `NTP_POOL`(pool.ntp.org), `TIMEZONE`, `SYNC_NOW`(true)   |

**Provision 定义格式：**

内置和用户自定义 provisions 使用以下 YAML 结构定义：

```yaml
desc: 人类可读的描述
defaults:
  privileged: true
  run: once
  env:
    required:
      - name: REQ_VAR
        desc: 必需变量的描述
    optional:
      - name: OPT_VAR
        value: "default_value"
        desc: 可选变量的描述
  script: script-name.sh
```

#### 用户自定义 Provisions

你可以使用 `user:` 前缀定义自己的可复用 provisions。用户 provisions 的工作方式与内置 provisions 相同，但定义在你的项目中。

**目录结构：**

运行 `radp-vf init` 后，你的项目将包含：

```
myproject/
└── config/
    ├── vagrant.yaml
    ├── vagrant-{env}.yaml
    └── provisions/
        ├── definitions/
        │   └── example.yaml      # Provision 定义
        └── scripts/
            └── example.sh        # Provision 脚本
```

**子目录支持：**

你可以将 provisions 组织到子目录中。子目录路径会成为 provision 名称的一部分：

```
provisions/
├── definitions/
│   ├── example.yaml              # -> user:example
│   ├── nfs/
│   │   └── external-mount.yaml   # -> user:nfs/external-mount
│   └── docker/
│       └── setup.yaml            # -> user:docker/setup
└── scripts/
    ├── example.sh
    ├── nfs/
    │   └── external-mount.sh     # 镜像 definitions 目录结构
    └── docker/
        └── setup.sh
```

**创建用户 provision：**

1. 在 `provisions/definitions/` 中创建定义文件：

```yaml
# config/provisions/definitions/docker/setup.yaml
description: 安装和配置 Docker
defaults:
  privileged: true
  run: once
required_env:
  - DOCKER_VERSION
script: setup.sh    # 脚本位于 provisions/scripts/docker/setup.sh
```

2. 在 `provisions/scripts/` 中创建脚本（镜像子目录结构）：

```bash
#!/usr/bin/env bash
# config/provisions/scripts/docker/setup.sh
set -euo pipefail

echo "[INFO] Installing Docker ${DOCKER_VERSION}"
# 安装逻辑...
```

3. 在 YAML 配置中使用：

```yaml
provisions:
  - name: user:docker/setup
    enabled: true
    env:
      DOCKER_VERSION: "24.0"
```

**路径解析：**

用户 provisions 使用与普通 provisions 相同的两级路径解析：

```
查找顺序：
1. {config_dir}/provisions/definitions/xxx.yaml
2. {project_root}/provisions/definitions/xxx.yaml
```

如果同一 provision 在两个位置都存在，`config_dir` 优先，并显示警告。

<details>
<summary><b>所有 provision 选项</b></summary>

| 选项            | 类型           | 默认值                  | 说明                                       |
|---------------|--------------|----------------------|------------------------------------------|
| `name`        | string       | -                    | provision 名称                             |
| `enabled`     | boolean      | `true`               | 是否启用                                     |
| `type`        | string       | `shell`              | 类型：`shell` 或 `file`                      |
| `privileged`  | boolean      | `false`              | 以 root 运行                                |
| `run`         | string       | `once`               | 运行时机：`once`、`always`、`never`             |
| `phase`       | string       | `pre`                | 执行阶段：`pre` 或 `post`（仅 common provisions） |
| `inline`      | string       | -                    | 内联脚本内容                                   |
| `path`        | string       | -                    | 外部脚本路径                                   |
| `args`        | string/array | -                    | 脚本参数                                     |
| `env`         | hash         | -                    | 环境变量                                     |
| `before`      | string       | -                    | 在指定 provision 之前运行                       |
| `after`       | string       | -                    | 在指定 provision 之后运行                       |
| `keep-color`  | boolean      | `false`              | 保持颜色输出                                   |
| `upload-path` | string       | `/tmp/vagrant-shell` | 脚本在虚拟机中的上传路径                             |
| `reboot`      | boolean      | `false`              | 执行后重启                                    |
| `reset`       | boolean      | `false`              | 执行后重置 SSH 连接                             |
| `sensitive`   | boolean      | `false`              | 隐藏输出（敏感数据）                               |
| `binary`      | boolean      | `false`              | 以二进制传输脚本（不转换行尾）                          |

**File provisioner 选项：**

| 选项            | 类型     | 说明         |
|---------------|--------|------------|
| `source`      | string | 宿主机上的源文件路径 |
| `destination` | string | 虚拟机上的目标路径  |

</details>

### 触发器 (triggers)

注意：`on` 键在 YAML 中必须加引号，否则会被解析为布尔值。

```yaml
triggers:
  - name: before-up               # 名称
    desc: '启动前触发器'            # 描述
    enabled: true
    "on": before                  # before 或 after（必须加引号！）
    type: action                  # action, command, hook
    action: # 触发的动作
      - up
      - reload
    only-on: # 过滤 guest（支持正则）
      - '/node-.*/'
    run:
      inline: |                   # 本地脚本
        echo "Starting..."
    # 或 run-remote 在虚拟机内执行
```

<details>
<summary><b>所有触发器选项</b></summary>

| 选项         | 类型           | 默认值      | 说明                                    |
|------------|--------------|----------|---------------------------------------|
| `name`     | string       | -        | 触发器名称                                 |
| `enabled`  | boolean      | `true`   | 是否启用                                  |
| `"on"`     | string       | `before` | 时机：`before` 或 `after`（在 YAML 中必须加引号！） |
| `type`     | string       | `action` | 作用域：`action`、`command` 或 `hook`       |
| `action`   | string/array | `[:up]`  | 触发的动作/命令（如 `up`、`destroy`、`reload`）   |
| `only-on`  | string/array | -        | 按 machine name 过滤；支持正则表达式 `/pattern/` |
| `ignore`   | string/array | -        | 忽略的动作                                 |
| `on-error` | string       | -        | 错误处理：`:halt`、`:continue`              |
| `abort`    | boolean      | `false`  | 触发器失败时中止 Vagrant 操作                   |
| `desc`     | string       | -        | 触发器运行前显示的描述/信息                        |
| `info`     | string       | -        | `desc` 的别名                            |
| `warn`     | string       | -        | 触发器运行前显示的警告信息                         |

**run 选项（宿主机执行）：**

| 选项       | 类型           | 说明           |
|----------|--------------|--------------|
| `inline` | string       | 在宿主机上运行的内联脚本 |
| `path`   | string       | 宿主机上的脚本路径    |
| `args`   | string/array | 传递给脚本的参数     |

**run-remote 选项（虚拟机内执行）：**

| 选项       | 类型           | 说明                 |
|----------|--------------|--------------------|
| `inline` | string       | 在虚拟机内运行的内联脚本       |
| `path`   | string       | 宿主机上的脚本路径（会上传到虚拟机） |
| `args`   | string/array | 传递给脚本的参数           |

</details>

#### 内置触发器

框架提供了用于常见系统配置任务的内置触发器。内置触发器以 `radp:` 前缀标识，在 `up` 或 `reload` 动作后在虚拟机内执行脚本。

**可用的内置触发器：**

| 名称                              | 描述                            | 默认时机            |
|---------------------------------|-------------------------------|-----------------|
| `radp:system/disable-swap`      | 禁用 swap 分区（Kubernetes 必需）     | after up/reload |
| `radp:system/disable-selinux`   | 禁用 SELinux（设置为 permissive 模式） | after up/reload |
| `radp:system/disable-firewalld` | 禁用 firewalld 服务               | after up/reload |

**使用方法：**

```yaml
triggers:
  # 禁用 swap（Kubernetes 必需）
  - name: radp:system/disable-swap
    enabled: true

  # 禁用 SELinux
  - name: radp:system/disable-selinux
    enabled: true

  # 禁用 firewalld
  - name: radp:system/disable-firewalld
    enabled: true
```

**覆盖默认值：**

用户配置优先于内置默认值：

```yaml
triggers:
  - name: radp:system/disable-swap
    enabled: true
    "on": after                # 覆盖时机（默认: after）
    action: up                 # 覆盖动作（默认: [up, reload]）
    on-error: halt             # 覆盖错误处理（默认: continue）
```

**内置触发器定义格式：**

内置触发器使用以下 YAML 结构定义：

```yaml
desc: 人类可读的描述
defaults:
  "on": after
  action:
    - up
    - reload
  type: action
  on-error: continue
  run-remote:
    script: script-name.sh
```

## 配置继承

框架支持两个层级的配置合并：

### 文件级合并

`vagrant.yaml`（基础）+ `vagrant-{env}.yaml`（环境）进行深度合并：

| 类型     | 合并行为                          |
|--------|-------------------------------|
| 标量     | 覆盖（env 优先）                    |
| 哈希     | 深度合并                          |
| 数组     | 拼接                            |
| **插件** | **按 name 合并**（env 扩展/覆盖 base） |

**插件合并示例：**

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

# 合并结果（按 name 合并）
plugins:
  - name: vagrant-hostmanager
    required: true                # 继承自 base
    options:
      manage_host: true           # 继承自 base
      manage_guest: true          # 继承自 base
      provisioner: enabled        # 从 env 新增
      ip_resolver: { ... }        # 从 env 新增
```

### Guest 级继承

在配置文件内，guest 设置继承自：**global common → cluster common → guest**

| 配置项                              | 合并行为                                                                       |
|----------------------------------|----------------------------------------------------------------------------|
| box, provider, network, hostname | 深度合并（guest 覆盖）                                                             |
| hostmanager                      | 深度合并（guest 覆盖）                                                             |
| provisions                       | 按 phase 拼接：`global-pre → cluster-pre → guest → cluster-post → global-post` |
| triggers                         | 拼接                                                                         |
| synced-folders                   | 拼接                                                                         |

**示例：**

```
Global common:
  - provisions: [A(pre), D(post)]
  - synced-folders: [X]

Cluster common:
  - provisions: [B(pre), E(post)]
  - synced-folders: [Y]

Guest:
  - provisions: [C]

Guest 最终结果:
  - provisions: [A, B, C, E, D]   # global-pre, cluster-pre, guest, cluster-post, global-post
  - synced-folders: [X, Y]        # 拼接
```

### 汇总表

| 配置项            | 文件合并 (base + env) | Guest 继承 (common → guest) |
|----------------|-------------------|---------------------------|
| plugins        | 按 name 合并         | 不适用（仅全局）                  |
| box            | 深度合并              | 深度合并                      |
| provider       | 深度合并              | 深度合并                      |
| network        | 深度合并              | 深度合并                      |
| hostname       | 覆盖                | 覆盖                        |
| hostmanager    | 深度合并              | 深度合并                      |
| provisions     | 拼接                | 按 phase 拼接                |
| triggers       | 拼接                | 拼接                        |
| synced-folders | 拼接                | 拼接                        |

## 约定优于配置

框架根据上下文自动应用合理的默认值：

| 字段                  | 默认值                          | 示例                      |
|---------------------|------------------------------|-------------------------|
| `hostname`          | `{guest-id}.{cluster}.{env}` | `node-1.my-cluster.dev` |
| `provider.name`     | `{env}-{cluster}-{guest-id}` | `dev-my-cluster-node-1` |
| `provider.group-id` | `{env}/{cluster}`            | `dev/my-cluster`        |

## 配置校验规则

框架会验证配置并在以下情况抛出错误：

- **重复的集群名称**: 同一环境文件中不允许存在同名集群
- **重复的 guest ID**: 同一集群内不允许存在相同的 guest ID
- **基础配置中定义集群**: 集群必须在 `vagrant-{env}.yaml` 中定义，不能在基础 `vagrant.yaml` 中定义

## 机器命名

Vagrant 机器名称使用 `provider.name`（默认: `{env}-{cluster}-{guest-id}`）以确保在 `$VAGRANT_DOTFILE_PATH/machines/<name>`
中的唯一性。这可以防止多个集群中存在相同 guest ID 时产生冲突。

## 模板系统

模板允许你使用预定义配置和变量替换来初始化项目。

### 模板位置

- **内置模板**: `$RADP_VF_HOME/templates/`
- **用户模板**: `~/.config/radp-vagrant/templates/`

同名的用户模板会覆盖内置模板。

### 创建自定义模板

1. 在 `~/.config/radp-vagrant/templates/my-template/` 下创建目录
2. 创建 `template.yaml` 元数据文件：

```yaml
name: my-template
desc: 我的自定义模板
version: 1.0.0
variables:
  - name: env
    desc: 环境名称
    default: dev
    required: true
  - name: cluster_name
    desc: 集群名称
    default: example
  - name: mem
    desc: 内存（MB）
    default: 2048
    type: integer
```

3. 创建 `files/` 目录存放模板文件
4. 在文件内容和文件名中使用 `{{variable}}` 占位符

示例：当 `env=dev` 时，`files/config/vagrant-{{env}}.yaml` 会变成 `files/config/vagrant-dev.yaml`。

## 环境变量

| 变量                        | 说明           |
|---------------------------|--------------|
| `RADP_VF_HOME`            | 框架安装目录（自动检测） |
| `RADP_VAGRANT_CONFIG_DIR` | 配置目录路径       |
| `RADP_VAGRANT_ENV`        | 覆盖环境名称       |

## 扩展

### 添加新插件配置器

1. 创建文件 `lib/radp_vagrant/configurators/plugins/my_plugin.rb`:

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

2. 添加到 `plugins/registry.rb`:

```ruby
require_relative 'my_plugin'

def plugin_classes
  [
    Hostmanager,
    Vbguest,
    Proxyconf,
    Bindfs,
    MyPlugin # 添加到这里
  ]
end
```

### 添加 Provider

```ruby
# 在 provider.rb 中
RadpVagrant::Configurators::Provider::CONFIGURATORS['vmware_desktop'] = lambda { |provider, opts|
  provider.vmx['memsize'] = opts['mem']
  provider.vmx['numvcpus'] = opts['cpus']
}
```

## CI

### 如何发布

1. 触发 `release-prep` 并指定 `bump_type`（patch/minor/major/manual，默认 patch）。若选择 manual，需提供 `vX.Y.Z`。此步骤会更新
   `version.rb` 并添加 changelog 条目（创建 `workflow/vX.Y.Z` 分支 + PR）。
2. 审核/编辑 PR 中的 changelog，然后合并到 `main`。
3. 后续工作流自动串联运行：
    - `create-version-tag` → 创建并推送 Git 标签
    - `release` → 创建包含归档文件的 GitHub Release
    - `update-homebrew-tap` → 更新 Homebrew formula

```
release-prep (手动触发)
       │
       ▼
   PR 合并
       │
       ▼
create-version-tag
       │
       ├──────────────┐
       ▼              ▼
   release    update-homebrew-tap
```

### GitHub Actions

#### CI (`ci.yml`)

- **触发**: 推送/PR 到 `main`。
- **目的**: 在 Ubuntu 和 macOS 上跨多个 Ruby 版本（3.0-3.3）验证 Ruby 语法、测试框架加载、配置加载和 Vagrantfile 生成。

#### Release prep (`release-prep.yml`)

- **触发**: 在 `main` 上手动触发（`workflow_dispatch`）。
- **目的**: 从解析的版本（patch/minor/major 升级或手动指定 `vX.Y.Z`）创建发布分支（`workflow/vX.Y.Z`），更新 `version.rb`，插入
  changelog 条目，并创建 PR 供审核。

#### Create version tag (`create-version-tag.yml`)

- **触发**: 在 `main` 上手动触发（`workflow_dispatch`），或合并 `workflow/vX.Y.Z` PR 时。
- **目的**: 从 `version.rb` 读取版本，验证 changelog 条目，然后创建/推送 Git 标签（如不存在）。

#### Release (`release.yml`)

- **触发**: `create-version-tag` 成功完成后、推送版本标签（`v*`）或手动触发（`workflow_dispatch`）。
- **目的**: 创建包含 tar.gz 和 zip 归档的 GitHub Release，从 changelog 提取发布说明。

#### Update Homebrew tap (`update-homebrew-tap.yml`)

- **触发**: `create-version-tag` 成功完成后、推送版本标签（`v*`）或手动触发（`workflow_dispatch`）。
- **目的**: 使用 `packaging/homebrew/radp-vagrant-framework.rb` 模板更新 Homebrew tap formula，替换版本和 SHA256。

## 许可证

MIT
