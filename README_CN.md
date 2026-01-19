# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

基于 YAML 配置的多机 Vagrant 环境管理框架。

## 特性

- **声明式 YAML 配置**: 通过 YAML 定义虚拟机、网络、配置脚本和触发器
- **多文件配置**: 基础配置 + 环境特定覆盖 (`vagrant.yaml` + `vagrant-{env}.yaml`)
- **配置继承**: Global → Cluster → Guest 三级继承，自动合并
- **数组连接**: provisions、triggers、synced-folders 在继承时累加而非覆盖
- **模块化插件系统**: 每个插件配置器独立文件，便于维护
- **约定优于配置**: 自动生成 hostname、provider name 和 group-id
- **调试支持**: 可导出最终合并后的配置用于检查

## 快速开始

```bash
cd src/main/ruby

# 验证配置
vagrant validate

# 查看虚拟机状态
vagrant status

# 启动所有虚拟机
vagrant up

# 启动指定虚拟机
vagrant up guest-1

# 调试: 导出合并后的配置
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"

# 调试: 导出指定 guest 的配置
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config', 'guest-1')"
```

## 目录结构

```
src/main/ruby/
├── Vagrantfile                     # 入口文件
├── config/
│   ├── vagrant.yaml                # 基础配置（设置 env）
│   ├── vagrant-dev.yaml            # Dev 环境集群
│   └── vagrant-local.yaml          # Local 环境集群
└── lib/
    ├── radp_vagrant.rb             # 主协调器
    └── radp_vagrant/
        ├── config_loader.rb        # 多文件 YAML 加载
        ├── config_merger.rb        # 深度合并（数组连接）
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

## 环境变量

- `RADP_VAGRANT_CONFIG_DIR` - 覆盖配置目录路径

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

## 许可证

MIT
