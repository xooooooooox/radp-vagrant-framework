# Installation Guide

## Prerequisites

- Ruby 2.7+ ([Installation](https://www.ruby-lang.org/en/documentation/installation/))
- Vagrant 2.0+ ([Installation](https://developer.hashicorp.com/vagrant/install))
- VirtualBox (or other supported provider)
- [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework) (required, automatically installed via Homebrew/package managers)

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

#### Script Options

```shell
bash install.sh --ref main
bash install.sh --ref v1.0.0-rc1
bash install.sh --mode manual
bash install.sh --mode dnf

curl -fsSL https://raw.githubusercontent.com/xooooooooox/homelabctl/main/install.sh | bash -s -- --ref main
```

| Option              | Description                                                              | Default                               |
|---------------------|--------------------------------------------------------------------------|---------------------------------------|
| `--ref <ref>`       | Install from a git ref (branch, tag, SHA). Implies manual install.       | latest release                        |
| `--mode <mode>`     | `auto`, `manual`, or specific: `homebrew`, `dnf`, `yum`, `apt`, `zypper` | `auto`                                |
| `--install-dir <d>` | Manual install location                                                  | `~/.local/lib/radp-vagrant-framework` |
| `--bin-dir <d>`     | Symlink location                                                         | `~/.local/bin`                        |

Environment variables (`RADP_VF_REF`, `RADP_VF_VERSION`, `RADP_VF_INSTALL_MODE`, `RADP_VF_INSTALL_DIR`,
`RADP_VF_BIN_DIR`) are also supported as fallbacks.

When `--ref` is used and a package-manager version is already installed, the script automatically removes it first to
avoid conflicts.

### Portable Binary

Download a self-contained portable binary from [GitHub Releases](https://github.com/xooooooooox/radp-vagrant-framework/releases):

| Platform            | Download                                                                                                                                         |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| macOS Apple Silicon | [radp-vf-portable-darwin-arm64](https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-darwin-arm64)   |
| macOS Intel         | [radp-vf-portable-darwin-amd64](https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-darwin-amd64)   |
| Linux x86_64        | [radp-vf-portable-linux-amd64](https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-linux-amd64)     |
| Linux ARM64         | [radp-vf-portable-linux-arm64](https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-linux-arm64)     |

```shell
# Example: macOS Apple Silicon
curl -fsSL https://github.com/xooooooooox/radp-vagrant-framework/releases/latest/download/radp-vf-portable-darwin-arm64 -o radp-vf
chmod +x radp-vf
sudo mv radp-vf /usr/local/bin/

# Verify installation
radp-vf --help
```

> **Note**: The portable binary requires [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework) to be installed. You can use the radp-bf portable binary or install via Homebrew/package managers.

### Manual (Git Clone)

First, install [radp-bash-framework](https://github.com/xooooooooox/radp-bash-framework):

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-bash-framework/main/install.sh | bash
```

Then clone radp-vagrant-framework:

```shell
git clone https://github.com/xooooooooox/radp-vagrant-framework.git
cd radp-vagrant-framework
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

## Uninstalling

### Uninstall Script (Recommended)

```shell
bash uninstall.sh
bash uninstall.sh --yes # Skip confirmation
```

The script auto-detects both package-manager and manual installations and removes them.

### Homebrew

```shell
brew uninstall radp-vagrant-framework
```

### Manual

```shell
rm -rf ~/.local/lib/radp-vagrant-framework
rm -f ~/.local/bin/radp-vf ~/.local/bin/radp-vagrant-framework
```

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

| Variable                            | Description                           | Default                         |
|-------------------------------------|---------------------------------------|---------------------------------|
| `RADP_VF_HOME`                      | Framework installation directory      | Auto-detected                   |
| `RADP_VAGRANT_CONFIG_DIR`           | Configuration directory path          | `./config` if exists            |
| `RADP_VAGRANT_ENV`                  | Override environment name             | `radp.env` in config file       |
| `RADP_VAGRANT_CONFIG_BASE_FILENAME` | Override base config filename         | Auto-detect: `vagrant.yaml` > `config.yaml` |
| `RADP_VF_PORTABLE`                  | Set by portable binary (read-only)    | Not set                         |
| `RADP_VF_PORTABLE_VERSION`          | Version of portable binary (read-only)| Not set                         |

**RADP_VF_HOME defaults:**

- Portable binary: `~/.cache/radp-vf/<version>`
- Script install: `~/.local/lib/radp-vagrant-framework`
- Homebrew install: `/opt/homebrew/Cellar/radp-vagrant-framework/<version>/libexec`
- Git clone: Project root (auto-detected)

**Priority (highest to lowest):**

```
Config dir:  -c flag > RADP_VAGRANT_CONFIG_DIR > ./config
Config file: RADP_VAGRANT_CONFIG_BASE_FILENAME > vagrant.yaml > config.yaml
Environment: -e flag > RADP_VAGRANT_ENV > radp.env in config file
```

**Custom config filename:**

```bash
# Use a custom base filename (supports any name)
export RADP_VAGRANT_CONFIG_BASE_FILENAME=myproject.yaml
# Will load: myproject.yaml + myproject-{env}.yaml
```

## VAGRANT_DOTFILE_PATH Recommendation

When using `RADP_VAGRANT_CONFIG_DIR` to run commands from any directory, set `VAGRANT_DOTFILE_PATH` to a fixed location:

```shell
# Add to ~/.bashrc or ~/.zshrc
export RADP_VAGRANT_CONFIG_DIR="$HOME/.config/radp-vagrant"
export VAGRANT_DOTFILE_PATH="$HOME/.config/radp-vagrant/.vagrant"
```

This prevents machine state from scattering across directories.
