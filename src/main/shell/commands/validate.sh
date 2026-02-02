#!/usr/bin/env bash
# @cmd
# @desc Validate YAML configuration files
# @option -c, --config <dir> Configuration directory
# @option -e, --env <name> Override environment name
# @example validate
# @example validate -c ./config
# @example validate -e prod

cmd_validate() {
  _vf_resolve_paths || return 1

  local config_dir
  config_dir="$(_vf_resolve_config_dir "validate")" || return 1

  echo "Validating configuration..." >&2
  echo "Config Dir: ${config_dir}" >&2
  echo "" >&2

  _vf_ruby_validate "$config_dir" "${opt_env:-}"
}
