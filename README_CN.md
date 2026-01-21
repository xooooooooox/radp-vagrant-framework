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
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/tools/install.sh | bash
```

或:

```shell
wget -qO- https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/tools/install.sh | bash
```

可选环境变量:

```shell
RADP_VF_VERSION=vX.Y.Z \
RADP_VF_REF=main \
RADP_VF_INSTALL_DIR="$HOME/.local/lib/radp-vagrant-framework" \
RADP_VF_BIN_DIR="$HOME/.local/bin" \
RADP_VF_ALLOW_ANY_DIR=1 \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/tools/install.sh)"
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

## 如何使用

### 初始化新项目

安装后，使用以下命令创建带有示例配置的新项目：

```shell
radp-vf init myproject
```

这会创建以下目录结构：

```
myproject/
└── config/
    ├── vagrant.yaml          # 基础配置（设置 env）
    └── vagrant-sample.yaml   # 环境特定集群配置
```

框架的 Vagrantfile 会通过 `radp-vf vg` 自动使用 - 项目目录中无需创建 Vagrantfile。

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

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `RADP_VF_HOME` | 框架安装目录 | 从脚本位置自动检测 |
| `RADP_VAGRANT_CONFIG_DIR` | 配置目录路径（`vg` 命令必需） | 当前目录下的 `./config`（如存在） |
| `RADP_VAGRANT_ENV` | 覆盖环境名称 | `vagrant.yaml` 中的 `radp.env` |

**RADP_VF_HOME 默认值：**
- 脚本/Homebrew 安装：`~/.local/lib/radp-vagrant-framework` 或 `/opt/homebrew/Cellar/radp-vagrant-framework/<version>/libexec`
- Git clone：`<repo>/src/main/ruby`（自动检测）

**环境优先级（从高到低）：**
```
-e 参数 > RADP_VAGRANT_ENV > vagrant.yaml 中的 radp.env
```

### 运行 Vagrant 命令

使用 `radp-vf vg` 运行 vagrant 命令。可以在项目目录中运行，也可以在设置了 `RADP_VAGRANT_CONFIG_DIR` 后从任意目录运行：

```shell
# 从项目目录运行（包含 config/vagrant.yaml）
cd myproject
radp-vf vg status
radp-vf vg up
radp-vf vg ssh sample-example-node-1
radp-vf vg halt
radp-vf vg destroy

# 或者设置 RADP_VAGRANT_CONFIG_DIR 后从任意目录运行
export RADP_VAGRANT_CONFIG_DIR="$HOME/myproject/config"
radp-vf vg status
radp-vf vg up

# 使用 -e 参数切换环境
radp-vf -e dev vg status      # 使用 vagrant-dev.yaml
radp-vf -e prod vg up         # 使用 vagrant-prod.yaml
```

**注意：** 原生 `vagrant` 命令与 `radp-vf vg` 相互隔离。在包含自己 Vagrantfile 的目录中运行 `vagrant up` 不会受 RADP Vagrant Framework 影响。

### 调试命令

```shell
# 显示环境信息
radp-vf info

# 导出合并后的配置（JSON）
radp-vf dump-config

# 按 guest ID 或 machine name 过滤
radp-vf dump-config node-1

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
src/main/ruby/
├── Vagrantfile                     # 入口文件
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
        └── configurators/
            ├── box.rb              # Box 配置
            ├── provider.rb         # Provider 配置（VirtualBox 等）
            ├── network.rb          # 网络和主机名
            ├── hostmanager.rb      # Guest 级别 hostmanager
            ├── synced_folder.rb    # 同步文件夹
            ├── provision.rb        # 配置脚本
            ├── trigger.rb          # 触发器
            ├── plugin.rb           # 插件协调器
            └── plugins/            # 模块化插件配置器
                ├── base.rb         # 基类
                ├── registry.rb     # 插件注册表
                ├── hostmanager.rb  # vagrant-hostmanager
                ├── vbguest.rb      # vagrant-vbguest
                ├── proxyconf.rb    # vagrant-proxyconf
                └── bindfs.rb       # vagrant-bindfs
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

# vagrant-sample.yaml - Dev 环境
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

```yaml
plugins:
  - name: vagrant-hostmanager     # 插件名称
    required: true                # 缺失时自动安装
    options:                      # 插件特定选项（使用下划线）
      enabled: true
      manage_host: true
      manage_guest: true
      include_offline: true
```

支持的插件：
- `vagrant-hostmanager` - 主机文件管理
- `vagrant-vbguest` - VirtualBox Guest Additions
- `vagrant-proxyconf` - 代理配置
- `vagrant-bindfs` - 绑定挂载（按 synced-folder 配置）

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
```

### 网络 (network)

```yaml
# 主机名在 guest 级别（默认: {guest-id}.{cluster}.{env}）
hostname: node.local

network:
  private-network:
    enabled: true
    type: dhcp                    # dhcp 或 static
    ip: 192.168.56.10             # static 类型时使用
    netmask: 255.255.255.0
  public-network:
    enabled: true
    type: static
    ip: 192.168.1.100
    bridge:
      - "en0: Wi-Fi"
  forwarded-ports:
    - enabled: true
      guest: 80
      host: 8080
      protocol: tcp
```

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
      smb-host: 192.168.1.1
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
    privileged: false             # 是否以 root 运行
    run: once                     # once, always, never
    inline: |                     # 内联脚本
      echo "Hello"
    # 或使用文件路径:
    # path: ./scripts/setup.sh
    # args: arg1 arg2
    # before: other-provision     # 在某脚本之前运行（脚本必须存在）
    # after: other-provision      # 在某脚本之后运行
```

### 触发器 (triggers)

注意：`on` 键在 YAML 中必须加引号，否则会被解析为布尔值。

```yaml
triggers:
  - name: before-up               # 名称
    desc: '启动前触发器'            # 描述
    enabled: true
    "on": before                  # before 或 after（必须加引号！）
    type: action                  # action, command, hook
    action:                       # 触发的动作
      - up
      - reload
    only-on:                      # 过滤 guest（支持正则）
      - '/node-.*/'
    run:
      inline: |                   # 本地脚本
        echo "Starting..."
    # 或 run-remote 在虚拟机内执行
```

## 配置继承

配置从 global → cluster → guest 流动。数组类型（provisions、triggers、synced-folders）会被**连接**而非替换：

```
Global common:
  - provisions: [A]
  - synced-folders: [X]

Cluster common:
  - provisions: [B]
  - synced-folders: [Y]

Guest:
  - provisions: [C]

Guest 最终结果:
  - provisions: [A, B, C]         # 全部累加
  - synced-folders: [X, Y]        # 全部累加
```

## 约定优于配置

框架根据上下文自动应用合理的默认值：

| 字段 | 默认值 | 示例 |
|------|--------|------|
| `hostname` | `{guest-id}.{cluster}.{env}` | `node-1.my-cluster.dev` |
| `provider.name` | `{env}-{cluster}-{guest-id}` | `dev-my-cluster-node-1` |
| `provider.group-id` | `{env}/{cluster}` | `dev/my-cluster` |

## 配置校验规则

框架会验证配置并在以下情况抛出错误：

- **重复的集群名称**: 同一环境文件中不允许存在同名集群
- **重复的 guest ID**: 同一集群内不允许存在相同的 guest ID
- **基础配置中定义集群**: 集群必须在 `vagrant-{env}.yaml` 中定义，不能在基础 `vagrant.yaml` 中定义

## 机器命名

Vagrant 机器名称使用 `provider.name`（默认: `{env}-{cluster}-{guest-id}`）以确保在 `$VAGRANT_DOTFILE_PATH/machines/<name>` 中的唯一性。这可以防止多个集群中存在相同 guest ID 时产生冲突。

## 环境变量

| 变量 | 说明 |
|------|------|
| `RADP_VF_HOME` | 框架安装目录（自动检测） |
| `RADP_VAGRANT_CONFIG_DIR` | 配置目录路径 |
| `RADP_VAGRANT_ENV` | 覆盖环境名称 |

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
    MyPlugin  # 添加到这里
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

1. 触发 `release-prep` 并指定 `bump_type`（patch/minor/major/manual，默认 patch）。若选择 manual，需提供 `vX.Y.Z`。此步骤会更新 `version.rb` 并添加 changelog 条目（创建 `workflow/vX.Y.Z` 分支 + PR）。
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
- **目的**: 从解析的版本（patch/minor/major 升级或手动指定 `vX.Y.Z`）创建发布分支（`workflow/vX.Y.Z`），更新 `version.rb`，插入 changelog 条目，并创建 PR 供审核。

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
