#!/usr/bin/env bash
# @cmd
# @desc Initialize a new project with sample configuration
# @arg dir Target directory (default: current directory)
# @option -t, --template <name> Use a template (default: base)
# @option --set <var>=<value>~ Set template variable (can be repeated)
# @flag --force Overwrite existing files
# @flag --dry-run Show what would be created without making changes
# @example init
# @example init myproject
# @example init -c /path/to/config
# @example init myproject -t k8s-cluster
# @example init myproject --template k8s-cluster --set cluster_name=homelab --set worker_count=3
# @example init myproject --dry-run
# @example init myproject --force

cmd_init() {
  _vf_resolve_paths || return 1

  # Determine target directory with priority:
  # gopt_config > RADP_VAGRANT_CONFIG_DIR > positional arg > .
  local target_dir
  if [[ -n "${gopt_config:-}" ]]; then
    target_dir="$gopt_config"
  elif [[ -n "${RADP_VAGRANT_CONFIG_DIR:-}" ]]; then
    target_dir="$RADP_VAGRANT_CONFIG_DIR"
  elif [[ -n "${1:-}" ]]; then
    target_dir="$1"
  else
    target_dir="."
  fi

  local template="${opt_template:-base}"
  local force="${opt_force:-false}"
  local dry_run="${opt_dry_run:-false}"

  # Create target directory (unless dry-run)
  if [[ "$dry_run" != "true" ]]; then
    mkdir -p "$target_dir"
  fi

  local abs_target_dir
  abs_target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || abs_target_dir="$target_dir"

  # Check if config already exists (unless --force)
  if [[ "$force" != "true" && "$dry_run" != "true" ]] && _vf_has_config_file "$abs_target_dir"; then
    radp_log_error "Configuration already exists in ${abs_target_dir}"
    radp_log_error "Use --force to overwrite"
    return 1
  fi

  echo "Initializing RADP Vagrant Framework configuration..."
  echo "Template: ${template}"
  [[ "$dry_run" == "true" ]] && echo "Mode: DRY-RUN"
  echo ""

  # Build variables hash as JSON for Ruby
  local vars_json="{"
  local first=true

  # Handle --set options (stored in opt_set array)
  if [[ -n "${opt_set:-}" ]]; then
    # opt_set might be a single value or space-separated values
    local var
    for var in ${opt_set}; do
      if [[ "$var" =~ ^([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        if [[ "$first" == "true" ]]; then
          first=false
        else
          vars_json+=","
        fi
        # Escape double quotes in value
        value="${value//\"/\\\"}"
        vars_json+="\"${key}\":\"${value}\""
      else
        radp_log_error "Invalid variable format '${var}'. Use var=value"
        return 1
      fi
    done
  fi
  vars_json+="}"

  # Call Ruby renderer (pass dry_run and force)
  local result
  result=$(_vf_ruby_init "$template" "$abs_target_dir" "$vars_json" "$dry_run" "$force") || true

  # Parse result
  local status
  status=$(echo "$result" | head -n1)

  if [[ "$status" != "SUCCESS" ]]; then
    local error_msg
    error_msg=$(echo "$result" | tail -n +2)
    radp_log_error "$error_msg"
    return 1
  fi

  # Get list of created and skipped files
  local files skipped_files
  files=$(echo "$result" | tail -n +2 | grep -v '^SKIPPED:' || true)
  skipped_files=$(echo "$result" | tail -n +2 | grep '^SKIPPED:' | sed 's/^SKIPPED://' || true)

  if [[ "$dry_run" == "true" ]]; then
    echo "Would create in ${abs_target_dir}/:"
  else
    echo "Configuration initialized successfully!"
    echo ""
    echo "Created in ${abs_target_dir}/:"
  fi
  echo "$files" | while read -r file; do
    [[ -n "$file" ]] && echo "  - ${file}"
  done

  if [[ -n "$skipped_files" ]]; then
    echo ""
    echo "Skipped (use --force to overwrite):"
    echo "$skipped_files" | while read -r file; do
      [[ -n "$file" ]] && echo "  - ${file}"
    done
  fi

  [[ "$dry_run" == "true" ]] && return 0

  echo ""
  echo "Framework:"
  echo "  RADP_VF_HOME: ${gr_vf_home}"
  echo "  Vagrantfile:  ${gr_vf_ruby_lib_dir}/Vagrantfile"
  echo ""
  echo "Provisions:"
  echo "  - Framework builtin:"
  echo "      radp:nfs/external-nfs-mount  - Mount external NFS shares"
  echo "      radp:ssh/host-trust          - Host -> Guest SSH trust"
  echo "      radp:ssh/cluster-trust       - Guest <-> Guest SSH trust"
  echo "      radp:time/chrony-sync        - Time synchronization"
  echo "  - User-defined: user:example (see provisions/definitions/example.yaml)"
  echo ""
  echo "Triggers:"
  echo "  - Framework builtin:"
  echo "      radp:system/disable-swap     - Disable swap (required for K8s)"
  echo "      radp:system/disable-selinux  - Disable SELinux"
  echo "      radp:system/disable-firewalld - Disable firewalld"
  echo "  - User-defined: user:example (see triggers/definitions/example.yaml)"
  echo ""
  echo "Next steps:"
  echo "  # Option 1: Run from project directory"
  echo "  cd ${abs_target_dir}"
  echo "  radp-vf vg status"
  echo ""
  echo "  # Option 2: Run from anywhere"
  echo "  radp-vf -c ${abs_target_dir} vg status"
  echo ""
  echo "Edit the config file (vagrant.yaml or config.yaml) to change 'env' and create your own environment file."
  echo "Add custom provisions in provisions/definitions/ with user: prefix."
  echo ""
  echo "Use 'radp-vf template list' to see all available templates."

  # Write result to file if RADP_VF_INIT_RESULT_FILE is set (for caller integration)
  if [[ -n "${RADP_VF_INIT_RESULT_FILE:-}" ]]; then
    echo "$abs_target_dir" > "$RADP_VF_INIT_RESULT_FILE"
  fi
}
