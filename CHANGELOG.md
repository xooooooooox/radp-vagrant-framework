# CHANGELOG

## v0.2.26

### feat

- Add application-level global options via `commands/_globals.sh`
    - `-c, --config <dir>` - Configuration directory (available for all commands)
    - `-e, --env <name>` - Override environment name (available for all commands)
    - Options can be placed before or after the command: `radp-vf -c /path list` or `radp-vf list -c /path`
- Add `RADP_VF_INIT_RESULT_FILE` environment variable support in `init` command
    - When set, writes the absolute config directory path to the specified file
    - Enables callers to get the actual initialized directory path
- Enhance `init` command to support `-c/--config` global option for specifying target directory
    - Priority: `-c/--config` > `RADP_VAGRANT_CONFIG_DIR` > positional arg > `.`

### changed

- Migrate per-command `-c/--config` and `-e/--env` options to application-level global options
    - Variables changed from `opt_config`/`opt_env` to `gopt_config`/`gopt_env`
    - Affected commands: list, vg, validate, dump-config, generate, info

### fix

- Fix ShellCheck SC2164: Add `|| return 1` to all `cd` commands in `ruby_bridge.sh`

## v0.2.25

### feat

- Add `--cluster` (`-C`) and `--guest-ids` (`-G`) options to `vg` command
  - Specify VMs by cluster name instead of full machine name: `radp-vf vg up -C gitlab-runner`
  - Filter specific guests within a cluster: `radp-vf vg up -C gitlab-runner -G 1,2`
  - Support multiple clusters: `radp-vf vg up -C cluster1,cluster2`
  - Original machine name syntax still supported: `radp-vf vg up homelab-gitlab-runner-1`
- Add shell completion support for cluster names and guest IDs
  - `radp-vf vg up --cluster=<TAB>` completes cluster names
  - `radp-vf vg up -C xxx --guest-ids=<TAB>` completes guest IDs for specified cluster
  - `radp-vf vg up <TAB>` completes machine names
- Add Ruby CLI modules for resolve and completion
  - `RadpVagrant::CLI::Resolve` - resolves cluster/guest-ids to machine names
  - `RadpVagrant::CLI::Completion` - provides completion data (machines, clusters, guests)
- Add COPR packaging support (`packaging/copr/radp-vagrant-framework.spec`)
- Add OBS packaging support (`packaging/obs/`) with Debian files
- Add GitHub workflows for COPR and OBS package builds
  - `update-spec-version.yml` - Auto-update spec version after tag creation
  - `build-copr-package.yml` - Trigger COPR build
  - `build-obs-package.yml` - Sync to OBS and trigger build
  - `build-portable.yml` - Build portable binary
- Generates completion script with delegation support via `_RADP_VF_DELEGATED` flag
- Support `privileged` on builtin or user trigger
- Add user triggers support with `user:` prefix
    - User triggers are project-defined triggers under `{config_dir}/triggers/` or `{project_root}/triggers/`
    - Supports subdirectory paths (e.g., `user:system/cleanup`)
    - Uses same definition format as builtin triggers
- Add triggers directory to project templates (base, single-node, k8s-cluster)
- Update `radp-vf init` output to show available triggers
- Add `inline` support for builtin/user provision definitions
    - Definitions can now use `inline: |...` instead of `script: xxx.sh`
    - User config can override definition's inline/script
- Add support for `config.yaml` as alternative base configuration filename
  - Auto-detection: `vagrant.yaml` (preferred) > `config.yaml`
  - New env var `RADP_VAGRANT_CONFIG_BASE_FILENAME` supports any custom filename
  - Environment files follow base filename pattern (e.g., `config-dev.yaml`)
- Add `vagrant-disksize` plugin support for disk resizing (e.g., Ubuntu boxes with 10GB default)
- Add `radp:system/expand-lvm` builtin provision to expand LVM partition and filesystem
- Display accurate version info when installed via `--ref <branch>` or `--ref <sha>`
- Generate `.install-version` file during manual installation
- Update `radp-vf version` to check `.install-version` first
- Add provision radp:crypto/gpg-preset-passphrase
- Add provision radp:git/clone and radp:yadm/clone
  - Support HTTPS and SSH clone
  - Support HTTPS authentication with token
  - Support SSH with key, host override, port override
  - Auto-detect target user when unprivileged
- Add builtin provision gpg-import
  - Support public key import from content, file, or keyserver
  - Support secret key import with passphrase
  - Support trust configuration via level or ownertrust file
  - Smart GPG_USERS handling: auto-detect when unprivileged, required when privileged
- Optimize builtin provision gpg-import
- Update shell completion with auto-generation support
- Consistent CLI args

### fix

- Fix shell completion pollution when config loading fails
    - Completion now silently returns empty results for invalid config paths
    - Changed error output from stdout to stderr in `base.rb` to prevent pollution
    - Added `load_config_silent` method in `completion.rb` for silent config loading
- Add dynamic completion support for zsh
    - Previously zsh completion only had static options without Ruby integration
    - Now supports cluster names, guest IDs, and machine names completion
    - Works with both direct `radp-vf` and delegated `homelabctl vf` commands
- Regenerate completion scripts
- Fix verbose mode not being passed to Vagrantfile
    - `radp-vf -v vg status` now correctly displays both framework and Vagrantfile banners
    - Changed detection from `opt_verbose` to `GX_RADP_FW_BANNER_MODE`
- Fix banner version
- Fix radp:yadm/clone
- Fix if hostname is empty, default to `<guest-id>.<cluster-name>.<env>`
- Fix `list -v` show the wrong value

### refactor

- Refactor CLI to use radp-bash-framework (radp-bf) architecture
    - Entry script reduced from ~1000 lines to ~15 lines
    - Commands auto-discovered from `src/main/shell/commands/`
    - Libraries auto-loaded from `src/main/shell/libs/`
    - Help text auto-generated from command annotations
    - Requires radp-bash-framework as dependency
- Add new directory structure: `src/main/shell/` with commands/, config/, libs/
- Preserve full backward compatibility for all command interfaces
- Backup legacy script as `bin/radp-vf.legacy`
- Remove backward compatibility constraints
    - Delete `bin/radp-vf.legacy` (legacy monolithic script)
    - Simplify `commands/completion.sh` from ~330 lines to ~17 lines using framework completion generation
- Regenerate shell completions using new CLI structure

### breaking

- Command options now come AFTER the command name (radp-bf framework convention)
    - Old: `radp-vf -c /path/to/config list -v`
    - New: `radp-vf list -c /path/to/config -a`
- Change `list -v, --verbose` to `list -a, --all` to avoid conflict with framework's global `-v` verbose option
- Add explicit short options for list command: `-p` (provisions), `-s` (synced-folders), `-t` (triggers)

### chore

- Update Homebrew formula to add radp-bash-framework dependency
- Update install.sh to check for radp-bash-framework and copy shell CLI layer
- Fix install script
- Add post-install message
- Update installation and uninstall scripts

### docs

- Update README.md and README_CN.md with radp-bash-framework dependency info
- Update CLAUDE.md with new CLI architecture documentation
- Document radp-bf framework integration and command annotation patterns
- Add "User-Defined Provisions & Triggers" section to README.md and README_CN.md
- Add "User Templates" section to README.md and README_CN.md
- Add "User Triggers" section to docs/configuration-reference.md
- Expand "Creating Custom Templates" section in docs/advanced.md with detailed guide
- Add "User Triggers System" section to CLAUDE.md
- Update directory structure in CLAUDE.md to include triggers
- Document script path resolution mechanism for provisions and triggers
- Document inline script support in definition format

## v0.1.11

### feat

- Optimize install.sh
- Add rebuild zsh completion cache instructions
- Add completion scripts
- Add template subcmd
- Add support for installing and copying project templates
- Add template management and rendering support
- Add `template` subcommand and support for project initialization with templates and variable customization
- Add base, list, and validate CLI classes to modularize command handling and improve code maintainability
- Error handling for provisions, synced folders, and triggers parsing functions
- Improve data validation and formatting for network, provisions, and triggers parsing
- Extend list command completions with detailed filtering options
- Enhance list command with detailed options and filtering support
- Add -o/--output option to CLI completions for dump-config command
- Add output file support to dump-config command with -o option
- Extend CLI completions with new commands and options
- Add list and validate commands, improve config handling, and enhance validation options
- Enhance RADP_VF_HOME and RUBY_LIB_DIR detection logic for development and installation modes
- Restructure shell scripts, remove install.sh, and simplify RADP CLI

### docs

- Update README with `-c` flag usage for running commands from any directory
- Add advanced topics and configuration reference guides
- Reorganize and update README with template and usage enhancements
- Update README with template system details and CLI usage
- Expand CLAUDE.md with template system usage and new CLI commands
- Update CLAUDE.md with details on new CLI module and hybrid architecture
- Update CLAUDE.md with verbose mode and filtering examples for list command
- Update README and README_CN with verbose mode and type filtering examples for list command
- Update CLAUDE.md to include new CLI commands, global options, and enhanced usage examples
- Update README to document new CLI options and commands
- Clarify RADP_VF_HOME defaults, update environment variables, and document CLI completions
- Update README
- Update vagrant sample configuration
- Update README to include new provision structure and triggers definitions

### refactor

- Simplify CLI `list` and `validate` commands by delegating logic to `RadpVagrant::CLI` classes

## v0.0.27

### feat

- Document builtin triggers system and usage details
- Add builtin trigger to disable firewalld, SELinux, and swap
- Add support for builtin trigger registry and resolution
- Add SSH cluster trust provision to enable seamless same-user VM access within clusters
- Add SSH host trust and chrony time sync predefined provisions
- Restructure NFS mount definition to enhance env variable descriptions
- Update user provision structure and enhance provision descriptions
- Refactor provision script handling and enhance default merging logic
- Support predefined builtin provisions and user predefined provisions
- Pad version placeholder to ensure consistent banner formatting
- Set default `privileged` option to false in provision settings
- Add setup and configuration details for vagrant-bindfs plugin
- Enhance vbguest configurator with extended options and hooks
- Implement deep merge for plugins by name
- Add support for vagrant-hostmanager plugin with provisioner mode and custom IP resolver
- Add provisioner mode for hostmanager
- Add phase field to common provisions
- Update homebrew formula
- Support multi static ips
- Optimize inited project
- Dynamically locates the framework using RADP_VF_HOME environment variable
- Run Vagrant from Anywhere
- MVP

### fix

- Ensure provisioner names support `--provision-with` compatibility for shell and file types
- Improve custom NTP server configuration and chrony service detection
- Resolve relative output path to absolute before directory change
- Add missing `pathname` require for path operations
- Fix homebrew formula

### docs

- Update README to document new SSH cluster trust provision
- Clarify SSH trust descriptions in provision help message
- Update README to include new SSH host trust and chrony time sync provisions
- Add comment for phase field in common provisions

### refactor

- Remove unused `name` variable from provision generation method

### chore

- Add missing `pathname` require for path operations
