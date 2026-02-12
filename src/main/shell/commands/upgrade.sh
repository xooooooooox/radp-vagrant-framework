#!/usr/bin/env bash
# @cmd
# @desc Upgrade radp-vf to the latest version
# @meta passthrough
# @flag --check Only check for updates
# @flag --force Force upgrade even if at latest
# @flag -y, --yes Skip confirmation prompt
# @option --version <version> Target specific version

cmd_upgrade() {
  radp_cli_upgrade_self "$@"
}
