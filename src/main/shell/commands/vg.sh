#!/usr/bin/env bash
# @cmd
# @desc Run vagrant command with framework
# @arg args~ Vagrant command and arguments
# @option -c, --config <dir> Configuration directory
# @option -e, --env <name> Override environment name
# @example vg status
# @example vg up
# @example vg ssh node-1
# @example vg halt
# @example vg destroy -f
# @example vg status -e dev
# @example vg -e dev status
# @example vg -c ./config up
# @example vg -- --help

cmd_vg() {
  # Handle no arguments - show help
  if [[ $# -eq 0 ]]; then
    radp_cli_help_command "vg"
    return 1
  fi

  _vf_resolve_paths || return 1

  local config_dir
  config_dir="$(_vf_resolve_config_dir "vg")" || return 1

  # Set environment override if specified
  if [[ -n "${opt_env:-}" ]]; then
    export RADP_VAGRANT_ENV="${opt_env}"
  fi

  # Use framework's Vagrantfile via VAGRANT_VAGRANTFILE
  export VAGRANT_VAGRANTFILE="${gr_vf_ruby_lib_dir}/Vagrantfile"
  export RADP_VAGRANT_CONFIG_DIR="${config_dir}"
  export RADP_VF_HOME="${gr_vf_home}"

  # Run vagrant with remaining arguments
  exec vagrant "$@"
}
