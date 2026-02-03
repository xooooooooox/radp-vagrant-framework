# RADP Vagrant Framework

```
    ____  ___    ____  ____     _    _____   __________  ___    _   ________
   / __ \/   |  / __ \/ __ \   | |  / /   | / ____/ __ \/   |  / | / /_  __/
  / /_/ / /| | / / / / /_/ /   | | / / /| |/ / __/ /_/ / /| | /  |/ / / /
 / _, _/ ___ |/ /_/ / ____/    | |/ / ___ / /_/ / _, _/ ___ |/ /|  / / /
/_/ |_/_/  |_/_____/_/         |___/_/  |_\____/_/ |_/_/  |_/_/ |_/ /_/

```

[![GitHub Release](https://img.shields.io/github/v/release/xooooooooox/radp-vagrant-framework?label=Release)](https://github.com/xooooooooox/radp-vagrant-framework/releases)

基于 YAML 配置的多机 Vagrant 环境管理框架，支持配置继承和模块化配置脚本。

## 特性

- **声明式 YAML 配置** - 通过 YAML 定义虚拟机、网络、配置脚本和触发器
- **多文件配置** - 基础配置 + 环境特定覆盖
- **配置继承** - Global → Cluster → Guest 三级继承
- **模板系统** - 通过预定义模板初始化项目
- **内置 Provisions & Triggers** - 使用 `radp:` 前缀的可复用组件

## 安装

```shell
# Homebrew（推荐）
brew tap xooooooooox/radp
brew install radp-vagrant-framework

# 脚本安装
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh | bash
```

## 快速开始

```shell
# 初始化项目
radp-vf init myproject --template k8s-cluster

# 运行 Vagrant 命令
radp-vf vg status
radp-vf vg up -C my-cluster
radp-vf vg ssh dev-my-cluster-node-1
```

## 配置示例

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

## 文档

详细文档请参阅英文版：

- [Getting Started](docs/getting-started.md) - 快速开始
- [Installation](docs/installation.md) - 安装指南
- [Configuration](docs/configuration.md) - 配置参考
- [User Guide](docs/user-guide/) - 用户指南
- [CLI Reference](docs/reference/cli-reference.md) - CLI 参考

## 相关项目

- [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework) - Bash CLI 框架（依赖）
- [homelabctl](https://github.com/xooooooooox/homelabctl) - Homelab 基础设施 CLI

## 许可证

[MIT](LICENSE)
