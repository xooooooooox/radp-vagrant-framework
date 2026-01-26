# Installation Guide

## Prerequisites

- Ruby 2.7+ ([Installation](https://www.ruby-lang.org/en/documentation/installation/))
- Vagrant 2.0+ ([Installation](https://developer.hashicorp.com/vagrant/install))
- VirtualBox (or other supported provider)

## Installation Methods

### Homebrew (macOS/Linux)

```shell
brew tap xooooooooox/radp
brew install radp-vagrant-framework
```

### Script (curl/wget)

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh
  | bash
```

Or:

```shell
wget -qO- https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh
  | bash
```

**Optional variables:**

```shell
RADP_VF_VERSION=vX.Y.Z \
  RADP_VF_REF=main \
  RADP_VF_INSTALL_DIR="$HOME/.local/lib/radp-vagrant-framework" \
  RADP_VF_BIN_DIR="$HOME/.local/bin" \
  RADP_VF_ALLOW_ANY_DIR=1 \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/install.sh)"
```

- `RADP_VF_REF` can be a branch, tag, or commit (takes precedence over `RADP_VF_VERSION`)
- Set `RADP_VF_ALLOW_ANY_DIR=1` for custom install directories not ending with `radp-vagrant-framework`
- Defaults: `~/.local/lib/radp-vagrant-framework` and `~/.local/bin`

### Manual (Git Clone)

```shell
git clone https://github.com/xooooooooox/radp-vagrant-framework.git
cd radp-vagrant-framework/src/main/ruby
```

Or download from [Releases](https://github.com/xooooooooox/radp-vagrant-framework/releases/latest).

## Upgrading

### Homebrew

```shell
brew upgrade radp-vagrant-framework
```

### Script

Re-run the installation script.

### Manual

`git pull` or download new release archive.

## Shell Completion

### Bash

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/completions/radp-vf.bash \
  >~/.local/share/bash-completion/completions/radp-vf

# Or source it in ~/.bashrc
echo 'source ~/.local/share/bash-completion/completions/radp-vf' >>~/.bashrc
```

### Zsh

```shell
mkdir -p ~/.zfunc

curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-vagrant-framework/main/completions/radp-vf.zsh \
  >~/.zfunc/_radp-vf

# Add to ~/.zshrc (before compinit)
echo 'fpath=(~/.zfunc $fpath)' >>~/.zshrc
```

## Environment Variables

| Variable                  | Description                      | Default                    |
|---------------------------|----------------------------------|----------------------------|
| `RADP_VF_HOME`            | Framework installation directory | Auto-detected              |
| `RADP_VAGRANT_CONFIG_DIR` | Configuration directory path     | `./config` if exists       |
| `RADP_VAGRANT_ENV`        | Override environment name        | `radp.env` in vagrant.yaml |

**RADP_VF_HOME defaults:**

- Script install: `~/.local/lib/radp-vagrant-framework`
- Homebrew install: `/opt/homebrew/Cellar/radp-vagrant-framework/<version>/libexec`
- Git clone: Project root (auto-detected)

**Priority (highest to lowest):**

```
-c flag > RADP_VAGRANT_CONFIG_DIR > ./config
-e flag > RADP_VAGRANT_ENV > radp.env in vagrant.yaml
```

## VAGRANT_DOTFILE_PATH Recommendation

When using `RADP_VAGRANT_CONFIG_DIR` to run commands from any directory, set `VAGRANT_DOTFILE_PATH` to a fixed location:

```shell
# Add to ~/.bashrc or ~/.zshrc
export RADP_VAGRANT_CONFIG_DIR="$HOME/.config/radp-vagrant"
export VAGRANT_DOTFILE_PATH="$HOME/.config/radp-vagrant/.vagrant"
```

This prevents machine state from scattering across directories.
