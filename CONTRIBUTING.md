# Contributing

## Development Setup

1. Install radp-bash-framework (required dependency):

```shell
curl -fsSL https://raw.githubusercontent.com/xooooooooox/radp-bash-framework/main/install.sh | bash
```

2. Clone the repository:

```shell
git clone https://github.com/xooooooooox/radp-vagrant-framework.git
cd radp-vagrant-framework
```

3. Run from source:

```shell
# Using the CLI (recommended)
./bin/radp-vf --help
./bin/radp-vf list
./bin/radp-vf validate
./bin/radp-vf dump-config

# Or using Ruby directly (for debugging)
cd src/main/ruby
vagrant validate
vagrant status
ruby -r ./lib/radp_vagrant -e "RadpVagrant.dump_config('config')"
```

## Code Style

- Ruby: frozen_string_literal, 2-space indent, snake_case
- YAML: 2-space indent, dash-case for keys (except plugin options use underscore)
- Triggers: `"on"` key must be quoted (YAML parses bare `on` as boolean)

## Release Process

### Workflow Chain

```
release-prep (manual trigger)
       │
       ▼
   PR merged
       │
       ▼
create-version-tag
       │
       ├───────────────────┬───────────────────┬──────────────────┬──────────────────┐
       ▼                   ▼                   ▼                  ▼                  ▼
build-copr-package  build-obs-package  update-homebrew-tap  build-portable  cleanup-branches
       │                   │                   │                  │
       └───────────────────┴───────────────────┴──────────────────┘
                                     │
                                     ▼
                        attach-release-packages
```

### Steps

1. Trigger `release-prep` workflow with `bump_type` (patch/minor/major/manual)
    - Creates branch `workflow/vX.Y.Z`
    - Updates `version.sh` and spec files
    - Regenerates completion scripts
    - Adds changelog entry
    - Opens PR for review

2. Review/edit the changelog in the PR and merge to `main`

3. Subsequent workflows run automatically:
    - `create-version-tag` → creates and pushes the Git tag
    - `build-copr-package` → builds RPM for Fedora/RHEL
    - `build-obs-package` → builds for openSUSE/Debian
    - `update-homebrew-tap` → updates the Homebrew formula
    - `build-portable` → builds portable binaries for all platforms
    - `attach-release-packages` → uploads built packages to GitHub Release

## GitHub Actions Reference

| Workflow                       | Trigger                                 | Purpose                                                                       |
|--------------------------------|-----------------------------------------|-------------------------------------------------------------------------------|
| `ci.yml`                       | Push/PR to `main`                       | Validate Ruby syntax, test across Ruby 3.1-3.3 on Ubuntu and macOS            |
| `release-prep.yml`             | Manual on `main`                        | Create release branch, update version.sh/specs, regenerate completions, PR    |
| `create-version-tag.yml`       | Merge of `workflow/vX.Y.Z` PR           | Read version, validate changelog, create/push Git tag                         |
| `build-copr-package.yml`       | After `create-version-tag`              | Build RPM package via COPR                                                    |
| `build-obs-package.yml`        | After `create-version-tag`              | Build packages via openSUSE Build Service                                     |
| `build-portable.yml`           | After `create-version-tag`              | Build portable binaries for all platforms (linux/darwin, amd64/arm64)         |
| `update-homebrew-tap.yml`      | After `create-version-tag`              | Update Homebrew tap formula with new version and SHA256                       |
| `attach-release-packages.yml`  | After build/homebrew workflows complete | Create GitHub Release and attach built packages                               |
| `update-spec-version.yml`      | After `create-version-tag`              | Verify spec file versions match release tag                                   |
| `cleanup-branches.yml`         | Weekly schedule or manual               | Delete stale workflow branches                                                |

## Required Secrets

Configure these secrets in GitHub repository settings (`Settings > Secrets and variables > Actions`):

### Homebrew Tap

| Secret               | Description                                               |
|----------------------|-----------------------------------------------------------|
| `HOMEBREW_TAP_TOKEN` | GitHub PAT with `repo` scope for homebrew-radp repository |

### COPR (Fedora/RHEL packages)

| Secret          | Description                       |
|-----------------|-----------------------------------|
| `COPR_LOGIN`    | COPR API login                    |
| `COPR_TOKEN`    | COPR API token                    |
| `COPR_USERNAME` | COPR username                     |
| `COPR_PROJECT`  | COPR project name                 |

### OBS (openSUSE/Debian packages)

| Secret         | Description                        |
|----------------|------------------------------------|
| `OBS_USERNAME` | openSUSE Build Service username    |
| `OBS_PASSWORD` | openSUSE Build Service password    |
| `OBS_PROJECT`  | OBS project name                   |
| `OBS_PACKAGE`  | OBS package name                   |

## Adding New Features

### Add New CLI Command

Commands are auto-discovered from `src/main/shell/commands/`:

1. Create file `src/main/shell/commands/my-command.sh` (or `my-group/subcommand.sh` for subcommands)
2. Add command metadata annotations:

```bash
#!/usr/bin/env bash
# @cmd
# @desc My command description
# @arg name! Required argument
# @option -o, --option <value> Optional flag

cmd_my_command() {
  # Access options via $opt_option
  # Access arguments via $1, $2, etc.
  # Call Ruby via _vf_ruby_* bridge functions
}
```

3. For commands that call Ruby, add bridge function in `src/main/shell/libs/vf/ruby_bridge.sh`

### Add New Plugin Configurator

1. Create file `lib/radp_vagrant/configurators/plugins/my_plugin.rb`
2. Implement `.plugin_name` and `.configure` methods
3. Add class to `plugins/registry.rb` `plugin_classes` array

### Add Builtin Provision

1. Create `lib/radp_vagrant/provisions/definitions/my-provision.yaml`
2. Create `lib/radp_vagrant/provisions/scripts/my-provision.sh`
3. Registry auto-discovers from YAML files (no code changes needed)

### Add Builtin Trigger

1. Create `lib/radp_vagrant/triggers/definitions/my-trigger.yaml`
2. Create `lib/radp_vagrant/triggers/scripts/my-trigger.sh`
3. Registry auto-discovers from YAML files (no code changes needed)

See [Advanced Topics](docs/advanced.md) for detailed examples.
