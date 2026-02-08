#!/usr/bin/env bash
# @cmd
# @desc List clusters and guests from configuration
# @arg filter Guest ID or machine name filter
# @flag -a, --all Show all detailed info
# @flag -p, --provisions Show provisions only
# @flag -s, --synced-folders Show synced folders only
# @flag -t, --triggers Show triggers only
# @flag -S, --status Show vagrant machine status
# @example list
# @example list --status
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

  if [[ "${opt_status:-false}" == "true" ]]; then
    export VAGRANT_VAGRANTFILE="${gr_vf_ruby_lib_dir}/Vagrantfile"
    export RADP_VF_HOME="${gr_vf_home}"
    export RADP_VAGRANT_CONFIG_DIR="${config_dir}"
  fi

  _vf_ruby_list "$config_dir" \
    "${gopt_env:-}" \
    "${opt_all:-false}" \
    "${opt_provisions:-false}" \
    "${opt_synced_folders:-false}" \
    "${opt_triggers:-false}" \
    "${1:-}" \
    "${opt_status:-false}"
}
