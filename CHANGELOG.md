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
