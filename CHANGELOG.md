# CHANGELOG

## v0.2.12

- docs: update docs
- feat: add builtin templates
- feat(radp-vf): update scaffold
- feat: Add user triggers support with `user:` prefix
- feat: Add user triggers support with `user:` prefix

## v0.2.12

### feat

- Add user triggers support with `user:` prefix
    - User triggers are project-defined triggers under `{config_dir}/triggers/` or `{project_root}/triggers/`
    - Supports subdirectory paths (e.g., `user:system/cleanup`)
    - Uses same definition format as builtin triggers
- Add triggers directory to project templates (base, single-node, k8s-cluster)
- Update `radp-vf init` output to show available triggers
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

- Fix banner version
- Fix radp:yadm/clone

### chore

- Fix install script
- Add post-install message
- Update installation and uninstall scripts

### docs

- Add "User-Defined Provisions & Triggers" section to README.md and README_CN.md
- Add "User Templates" section to README.md and README_CN.md
- Add "User Triggers" section to docs/configuration-reference.md
- Expand "Creating Custom Templates" section in docs/advanced.md with detailed guide
- Add "User Triggers System" section to CLAUDE.md
- Update directory structure in CLAUDE.md to include triggers

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