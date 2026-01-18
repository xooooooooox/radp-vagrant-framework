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
- **配置继承**: Global → Cluster → Guest 三级继承，自动合并
- **数组连接**: provisions、triggers、synced-folders 在继承时累加而非覆盖
- **可扩展设计**: 插件和 Provider 注册表，易于扩展
- **多集群支持**: 将虚拟机组织为逻辑集群

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
vagrant up dev-node-1
```

## 目录结构

```
src/main/ruby/
├── Vagrantfile                 # 入口文件
├── config/
│   └── vagrant.yaml            # 用户配置
└── lib/
    ├── radp_vagrant.rb         # 主协调器
    └── radp_vagrant/
        ├── config_loader.rb    # YAML 加载与验证
        ├── config_merger.rb    # 深度合并（数组连接）
        ├── generator.rb        # Vagrantfile 生成器
        └── configurators/
            ├── box.rb          # Box 配置
            ├── provider.rb     # Provider 配置（VirtualBox 等）
            ├── network.rb      # 网络配置
            ├── synced_folder.rb # 同步文件夹
            ├── provision.rb    # 配置脚本
            ├── trigger.rb      # 触发器
            └── plugin.rb       # 插件管理
```

## 配置结构

```yaml
radp:
  env: default
  extend:
    vagrant:
      # 插件管理
      plugins:
        - name: vagrant-hostmanager
          enabled: true
          options:
            enabled: true
            manage-host: true

      config:
        # 全局公共配置（被所有 guest 继承）
        common:
          synced-folders:
            basic:
              - enabled: true
                host: ./shared
                guest: /vagrant/shared
          provisions:
            - name: global-init
              enabled: true
              type: shell
              freq: once
              inline: echo "Hello"
          triggers:
            - name: startup
              enabled: true
              cycle: before
              type: actions
              action: [:up]
              run:
                inline: echo "Starting..."

        # 集群定义
        clusters:
          - name: my-cluster
            common:
              box:
                name: generic/centos9s
                version: 4.3.12
              provider:
                type: virtualbox
                mem: 2048
                cpus: 2

            guests:
              - id: node-1
                provider:
                  name: node-1
                  mem: 4096
                network:
                  hostname: node-1.local
                  private-network:
                    enabled: true
                    type: dhcp
```

## 配置参考

### 插件 (plugins)

```yaml
plugins:
  - name: vagrant-hostmanager    # 插件名称
    enabled: true                # 启用/禁用
    options:                     # 插件特定选项
      enabled: true
      manage-host: true
      manage-guest: true
```

### Box

```yaml
box:
  name: generic/centos9s         # Box 名称
  version: 4.3.12                # Box 版本
  check-update: false            # 禁用更新检查
```

### Provider

```yaml
provider:
  type: virtualbox               # Provider 类型
  name: my-vm                    # Provider 中的虚拟机名称
  group-id: my-group             # VirtualBox 分组
  mem: 2048                      # 内存（MB）
  cpus: 2                        # CPU 数量
  gui: false                     # 显示 GUI
```

### 网络 (network)

```yaml
network:
  hostname: node.local           # 虚拟机主机名
  private-network:
    enabled: true
    type: dhcp                   # dhcp 或 static
    ip: 192.168.56.10            # static 类型时使用
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
  hostmanager:
    enabled: true
    aliases:
      - myhost.local
```

### 同步文件夹 (synced-folders)

```yaml
synced-folders:
  basic:
    - enabled: true
      host: ./data               # 主机路径
      guest: /data               # 虚拟机挂载路径
      create: true               # 不存在时创建
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
  - name: setup                  # 名称
    desc: '配置脚本描述'          # 描述
    enabled: true
    type: shell                  # shell 或 file
    privileged: false            # 是否以 root 运行
    freq: once                   # once, always, never
    inline: |                    # 内联脚本
      echo "Hello"
    # 或使用文件路径:
    # path: ./scripts/setup.sh
    # args: arg1 arg2
    before: other-provision      # 在某脚本之前运行
    after: other-provision       # 在某脚本之后运行
```

### 触发器 (triggers)

```yaml
triggers:
  - name: before-up              # 名称
    desc: '启动前触发器'          # 描述
    enabled: true
    cycle: before                # before 或 after
    type: actions                # actions, hooks, commands
    action:                      # 触发的动作
      - :up
      - :reload
    only-on:                     # 过滤 guest（支持正则）
      - '/node-.*/'
    run:
      inline: |                  # 本地脚本
        echo "Starting..."
    # 或 run_remote 在虚拟机内执行
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
  - provisions: [A, B, C]        # 全部累加
  - synced-folders: [X, Y]       # 全部累加
```

## 生成 Vagrantfile 用于检查

生成独立的 Vagrantfile 以检查解析后的配置是否符合预期：

```bash
cd src/main/ruby

# 生成 Vagrantfile
ruby lib/radp_vagrant/generator.rb

# 使用自定义配置路径
ruby lib/radp_vagrant/generator.rb config/vagrant.yaml

# 输出到文件
ruby lib/radp_vagrant/generator.rb > Vagrantfile.generated

# 验证生成的文件
ruby -c Vagrantfile.generated
```

生成的 Vagrantfile 是独立的，不依赖框架，可直接用于标准 Vagrant 环境。

## 环境变量

- `RADP_VAGRANT_CONFIG` - 覆盖配置文件路径

## 扩展

### 添加 Provider

```ruby
# 在 provider.rb 中
RadpVagrant::Configurators::Provider::CONFIGURATORS['vmware_desktop'] = lambda { |provider, opts|
  provider.vmx['memsize'] = opts['mem']
  provider.vmx['numvcpus'] = opts['cpus']
}
```

### 添加插件

```ruby
# 在 plugin.rb 中
RadpVagrant::Configurators::Plugin::CONFIGURATORS['my-plugin'] = lambda { |config, opts|
  config.my_plugin.option = opts['value']
}
```

## 许可证

MIT
