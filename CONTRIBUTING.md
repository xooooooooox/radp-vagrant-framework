# Contributing

## Development Setup

1. Clone the repository:

```shell
git clone https://github.com/xooooooooox/radp-vagrant-framework.git
cd radp-vagrant-framework
```

2. Run from source:

```shell
cd src/main/ruby

# Validate configuration
vagrant validate

# Show VM status
vagrant status

# Debug: dump merged configuration
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
       ├──────────────┐
       ▼              ▼
   release    update-homebrew-tap
```

### Steps

1. Trigger `release-prep` workflow with `bump_type` (patch/minor/major/manual)
    - Creates branch `workflow/vX.Y.Z`
    - Updates `version.rb`
    - Adds changelog entry
    - Opens PR for review

2. Review/edit the changelog in the PR and merge to `main`

3. Subsequent workflows run automatically:
    - `create-version-tag` → creates and pushes the Git tag
    - `release` → creates GitHub Release with archives
    - `update-homebrew-tap` → updates the Homebrew formula

## GitHub Actions Reference

| Workflow                  | Trigger                                 | Purpose                                                                   |
|---------------------------|-----------------------------------------|---------------------------------------------------------------------------|
| `ci.yml`                  | Push/PR to `main`                       | Validate Ruby syntax, test across Ruby 3.1-3.3 on Ubuntu and macOS        |
| `release-prep.yml`        | Manual on `main`                        | Create release branch, update version.rb, insert changelog entry, open PR |
| `create-version-tag.yml`  | Manual or merge of `workflow/vX.Y.Z` PR | Read version, validate changelog, create/push Git tag                     |
| `release.yml`             | After `create-version-tag` or tag push  | Create GitHub Release with tar.gz and zip archives                        |
| `update-homebrew-tap.yml` | After `create-version-tag` or tag push  | Update Homebrew tap formula with new version and SHA256                   |

## Required Secrets

Configure these secrets in GitHub repository settings (`Settings > Secrets and variables > Actions`):

### Homebrew Tap

| Secret               | Description                                               |
|----------------------|-----------------------------------------------------------|
| `HOMEBREW_TAP_TOKEN` | GitHub PAT with `repo` scope for homebrew-radp repository |

## Adding New Features

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
