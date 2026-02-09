#!/usr/bin/env bash
# @cmd
# @desc Run vagrant command with framework
# @meta passthrough
# @example vg status
# @example vg up
# @example vg ssh node-1
# @example vg halt
# @example vg destroy -f
# @example vg status -e dev
# @example vg -e dev status
# @example vg -c ./config up
# @example vg up -C my-cluster
# @example vg up -C my-cluster -G 1,2
# @example vg up -C cluster1,cluster2
# @example vg provision vm --provision-with 'provisioner'
# @example vg -- --help
#
# Options (extracted before passing remaining args to vagrant):
#   -C, --cluster <names>    Cluster names (comma-separated for multiple)
#   -G, --guest-ids <ids>    Guest IDs (comma-separated, requires --cluster)

cmd_vg() {
  # Manually extract -C/--cluster and -G/--guest-ids from args,
  # forwarding everything else (including vagrant-specific options) to vagrant.
  local opt_cluster="" opt_guest_ids=""
  local vagrant_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -C|--cluster)       opt_cluster="$2"; shift 2 ;;
      -C=*|--cluster=*)   opt_cluster="${1#*=}"; shift ;;
      -G|--guest-ids)     opt_guest_ids="$2"; shift 2 ;;
      -G=*|--guest-ids=*) opt_guest_ids="${1#*=}"; shift ;;
      *)                  vagrant_args+=("$1"); shift ;;
    esac
  done

  # Restore positional parameters to vagrant_args
  if [[ ${#vagrant_args[@]} -gt 0 ]]; then
    set -- "${vagrant_args[@]}"
  else
    set --
  fi

  # Handle no arguments - show help (unless --cluster is specified)
  if [[ $# -eq 0 && -z "${opt_cluster:-}" ]]; then
    radp_cli_help_command "vg"
    return 1
  fi

  _vf_resolve_paths || return 1

  local config_dir
  config_dir="$(_vf_resolve_config_dir "vg")" || return 1

  # Set environment override if specified
  if [[ -n "${gopt_env:-}" ]]; then
    export RADP_VAGRANT_ENV="${gopt_env}"
  fi

  # Use framework's Vagrantfile via VAGRANT_VAGRANTFILE
  export VAGRANT_VAGRANTFILE="${gr_vf_ruby_lib_dir}/Vagrantfile"
  export RADP_VAGRANT_CONFIG_DIR="${config_dir}"
  export RADP_VF_HOME="${gr_vf_home}"

  # Pass verbose mode to Vagrantfile if radp-bf verbose/debug flag is set
  # Note: Global -v/--verbose sets GX_RADP_FW_BANNER_MODE, not opt_verbose
  if [[ "${GX_RADP_FW_BANNER_MODE:-}" == "on" ]]; then
    export RADP_VAGRANT_VERBOSE=1
  fi

  # If --cluster is specified, resolve to machine names
  local resolved_machines=()
  if [[ -n "${opt_cluster:-}" ]]; then
    local guest_ids_arg=""
    if [[ -n "${opt_guest_ids:-}" ]]; then
      guest_ids_arg="--guest-ids=${opt_guest_ids}"
    fi

    # Parse comma-separated cluster names into array
    local clusters=()
    IFS=',' read -ra clusters <<< "${opt_cluster}"

    local cluster_args=()
    for cluster in "${clusters[@]}"; do
      cluster_args+=("--cluster=${cluster}")
    done

    mapfile -t resolved_machines < <(_vf_ruby_resolve "$config_dir" "${gopt_env:-}" "${cluster_args[@]}" $guest_ids_arg)

    if [[ ${#resolved_machines[@]} -eq 0 ]]; then
      radp_log_error "No machines found for specified cluster(s)"
      return 1
    fi
  fi

  # Run vagrant with remaining arguments and resolved machines
  if [[ ${#resolved_machines[@]} -gt 0 ]]; then
    exec vagrant "$@" "${resolved_machines[@]}"
  else
    exec vagrant "$@"
  fi
}

#######################################
# Completion function for --cluster option
# Returns list of cluster names
#######################################
_vg_comp_clusters() {
  _vf_resolve_paths 2>/dev/null || return
  local config_dir
  config_dir="$(_vf_resolve_config_dir "vg" 2>/dev/null)" || return
  _vf_ruby_completion "$config_dir" "${RADP_VAGRANT_ENV:-}" "clusters"
}

#######################################
# Completion function for --guest-ids option
# Returns list of guest IDs for specified cluster(s)
#######################################
_vg_comp_guest_ids() {
  _vf_resolve_paths 2>/dev/null || return
  local config_dir
  config_dir="$(_vf_resolve_config_dir "vg" 2>/dev/null)" || return
  # Use first cluster from comma-separated opt_cluster if available
  local cluster=""
  if [[ -n "${opt_cluster:-}" ]]; then
    cluster="${opt_cluster%%,*}"  # Get first cluster before comma
  fi
  _vf_ruby_completion "$config_dir" "${RADP_VAGRANT_ENV:-}" "guests" "$cluster"
}

#######################################
# Completion function for machine names (positional args)
# Returns list of all machine names
#######################################
_vg_comp_machines() {
  _vf_resolve_paths 2>/dev/null || return
  local config_dir
  config_dir="$(_vf_resolve_config_dir "vg" 2>/dev/null)" || return
  _vf_ruby_completion "$config_dir" "${RADP_VAGRANT_ENV:-}" "machines"
}
