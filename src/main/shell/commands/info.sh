#!/usr/bin/env bash
# @cmd
# @desc Show environment and configuration info
# @option -c, --config <dir> Configuration directory
# @option -e, --env <name> Override environment name
# @example info
# @example info -c ./config
# @example info -e prod

cmd_info() {
  _vf_resolve_paths || return 1

  # Config dir is optional for info command
  local config_dir
  config_dir="$(_vf_resolve_config_dir 2>/dev/null)" || config_dir=""

  _vf_ruby_info "$config_dir" "${opt_env:-}"
}
