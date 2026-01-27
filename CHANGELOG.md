## v0.1.11 - 2026-01-27

- 44a6fed chore: Optimize install.sh
- 666106c docs: update README with `-c` flag usage for running commands from any directory
## v0.1.10 - 2026-01-26

- cdddcda docs: add advanced topics and configuration reference guides
## v0.1.9 - 2026-01-26

- 12ef36b feat: Add rebuild zsh completion cache instructions
- 5bcec51 feat: Add completion scripts
- 03bd468 feat: Add template subcmd
## v0.1.8 - 2026-01-25

- 69e4ecf feat: add support for installing and copying project templates
## v0.1.7 - 2026-01-25

- 873d6be docs: reorganize and update README with template and usage enhancements
- d02a76f docs: update README with template system details and CLI usage
- ec70abc docs: expand CLAUDE.md with template system usage and new CLI commands
- 34e7da1 feat: add template management and rendering support
- 5f0a65c feat: add `template` subcommand and support for project initialization with templates and variable customization
## v0.1.6 - 2026-01-25

- ce97f66 Release prep v0.1.6
- 542e0f5 docs: update CLAUDE.md with details on new CLI module and hybrid architecture
- 8cc9ebd feat: add base, list, and validate CLI classes to modularize command handling and improve code maintainability
- 0f55cf8 feat: add base, list, and validate CLI classes to modularize command handling and improve code maintainability
- 51d38b2 refactor: simplify CLI `list` and `validate` commands by delegating logic to `RadpVagrant::CLI` classes
## v0.1.6 - 2026-01-25

- 542e0f5 docs: update CLAUDE.md with details on new CLI module and hybrid architecture
- 8cc9ebd feat: add base, list, and validate CLI classes to modularize command handling and improve code maintainability
- 0f55cf8 feat: add base, list, and validate CLI classes to modularize command handling and improve code maintainability
- 51d38b2 refactor: simplify CLI `list` and `validate` commands by delegating logic to `RadpVagrant::CLI` classes
## v0.1.5 - 2026-01-25

- 99eb1c3 refactor: add error handling for provisions, synced folders, and triggers parsing functions
## v0.1.4 - 2026-01-25

- ea2a971 refactor: improve data validation and formatting for network, provisions, and triggers parsing
## v0.1.3 - 2026-01-25

- 12bf1fa docs: update CLAUDE.md with verbose mode and filtering examples for list command
- bcecba9 docs: update README and README_CN with verbose mode and type filtering examples for list command
- 018f2de feat: extend list command completions with detailed filtering options
- 80925fd feat: enhance list command with detailed options and filtering support
## v0.1.2 - 2026-01-25

- 33a109d docs: update CLAUDE.md to include new CLI commands, global options, and enhanced usage examples
- 0296f0f docs: update README to document new CLI options and commands, including -c and -e flags, global options, and extended usage examples
- f95427b feat: add -o/--output option to CLI completions for dump-config command
- db9816b feat: add output file support to dump-config command with -o option
- f57637b feat: extend CLI completions with new commands and options, improve dump-config handling, and refine argument parsing
- 0b7dd76 feat: add list and validate commands, improve config handling, and enhance validation options
## v0.1.1 - 2026-01-25

- 371d914 docs: clarify RADP_VF_HOME defaults, update environment variables, and document CLI completions
- dd257ba refactor: enhance RADP_VF_HOME and RUBY_LIB_DIR detection logic for development and installation modes
## v0.1.0 - 2026-01-25

- 41c480e refactor: restructure shell scripts, remove install.sh, and simplify RADP CLI
- f1d97b0 docs: Update README
- dac2206 chore: update vagrant sample configuration
- e0255e5 docs(provisions): update README to include new provision structure and triggers definitions
## v0.0.27 - 2026-01-23

- 90ef974 docs(triggers): document builtin triggers system and usage details
- 6ca7564 feat(triggers): add builtin trigger to disable firewalld, SELinux, and swap
- c4ac685 feat(triggers): add support for builtin trigger registry and resolution
- b74c056 refactor(generator): remove unused `name` variable from provision generation method
## v0.0.26 - 2026-01-23

- 26ddf2c fix(provision): ensure provisioner names support `--provision-with` compatibility for shell and file types
- 6b76582 fix(provision): improve custom NTP server configuration and chrony service detection
## v0.0.25 - 2026-01-23

- 1c37753 fix(radp-vf): resolve relative output path to absolute before directory change
- 8ff4fb4 chore(path_resolver): add missing `pathname` require for path operations
## v0.0.24 - 2026-01-23

- 17ae299 docs: update README to document new SSH cluster trust provision
- 5bad091 docs(shell): clarify SSH trust descriptions in provision help message
- 4cf48c4 feat(provision): add SSH cluster trust provision to enable seamless same-user VM access within clusters

## v0.0.23 - 2026-01-23

- e076122 docs: update README to include new SSH host trust and chrony time sync provisions
- 288a2b8 feat(provision): add SSH host trust and chrony time sync predefined provisions
- b54cac9 feat(provision): restructure NFS mount definition to enhance env variable descriptions
- 850a1b2 feat(provision): update user provision structure and enhance provision descriptions
- 7c67c8d feat(provision): refactor provision script handling and enhance default merging logic

## v0.0.22 - 2026-01-23

- Support predefined builitin provisions and user predefined provisions
- Pad version placeholder to ensure consistent banner formatting
- Set default `privileged` option to false in provision settings

## v0.0.16 - 2026-01-22

- feat(bindfs): Add setup and configuration details for vagrant-bindfs plugin

## v0.0.15 - 2026-01-22

- feat(vbguest): Enhance vbguest configurator with extended options and hooks

## v0.0.14 - 2026-01-22

- feat(config): Implement deep merge for plugins by name

## v0.0.13 - 2026-01-22

- feat(hostmanager): Add support for vagrant-hostmanager plugin with provisioner mode and custom IP resolver

## v0.0.12 - 2026-01-22

- feat(hostmanager): Add provisioner mode
- docs: Add comment for phase field in common provisions

## v0.0.11 - 2026-01-22

- fix: fix homebrew formula

## v0.0.10 - 2026-01-22

- feat(formula): Update homebrew formula
- feat(provisions): Add phase field to common provisions

## v0.0.9 - 2026-01-22

- feat(network): Support multi static ips

## v0.0.8 - 2026-01-21

- feat: Optimize inited project

## v0.0.7 - 2026-01-21

- fix: dynamically locates the framework using RADP_VF_HOME environment variable, with fallback to local lib directory

## v0.0.6 - 2026-01-21

- Run Vagrant from Anywhere

## v0.0.5 - 2026-01-20

- mvp
