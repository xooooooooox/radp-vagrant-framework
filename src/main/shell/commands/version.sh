#!/usr/bin/env bash
# @cmd
# @desc Show radp-vagrant-framework version

# Version declaration - parsed by framework for --config and banner display
# NOTE: This value should be kept in sync with src/main/ruby/lib/radp_vagrant/version.rb
# Update this when releasing a new version
declare -gr gr_app_version="v0.2.23"

cmd_version() {
  # Get version from Ruby (single source of truth)
  local version
  version="$(_vf_get_ruby_version)" || version="${gr_app_version}"
  echo "radp-vf $(radp_get_install_version "$version")"
}
