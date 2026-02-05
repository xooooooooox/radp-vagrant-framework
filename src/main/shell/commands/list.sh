#!/usr/bin/env bash
# @cmd
# @desc List clusters and guests from configuration
# @arg filter Guest ID or machine name filter
# @option -a, --all Show all detailed info
# @option -p, --provisions Show provisions only
# @option -s, --synced-folders Show synced folders only
# @option -t, --triggers Show triggers only
# @example list
# @example list -a
# @example list -a node-1
# @example list -p
# @example list -s node-1
# @example list -t
# @example list -c /path/to/config

cmd_list() {
  _vf_resolve_paths || return 1

  local config_dir
  config_dir="$(_vf_resolve_config_dir "list")" || return 1

  _vf_ruby_list "$config_dir" \
"${gopt_env:-}"\
    "${opt_all:-false}" \
    "${opt_provisions:-false}" \
    "${opt_synced_folders:-false}" \
    "${opt_triggers:-false}" \
    "${1:-}"
}
