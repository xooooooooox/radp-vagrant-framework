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
  local orchestrated="${RADP_INIT_ORCHESTRATED:-false}"

  # Create target directory (unless dry-run)
  if [[ "$dry_run" != "true" ]]; then
    mkdir -p "$target_dir"
  fi

  local abs_target_dir
  abs_target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || abs_target_dir="$target_dir"
  local display_dir="${abs_target_dir/#$HOME/~}"

  # Check if config already exists (unless --force)
  if [[ "$force" != "true" && "$dry_run" != "true" ]] && _vf_has_config_file "$abs_target_dir"; then
    radp_log_error "Configuration already exists in ${abs_target_dir}"
    radp_log_error "Use --force to overwrite"
    return 1
  fi

  # Print header
  if [[ "$orchestrated" == "true" ]]; then
    echo "[vf] ${display_dir}/ (template: ${template})"
  else
    local header="Initializing RADP Vagrant Framework configuration..."
    [[ "$dry_run" == "true" ]] && header="$header (dry-run)"
    echo "$header"
    echo "Template: ${template}"
    echo ""
    echo "${display_dir}/"
  fi

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

  # Get list of created, overwritten, and skipped files
  local created_files overwritten_files skipped_files
  created_files=$(echo "$result" | tail -n +2 | grep -v '^SKIPPED:' | grep -v '^OVERWRITTEN:' || true)
  overwritten_files=$(echo "$result" | tail -n +2 | grep '^OVERWRITTEN:' | sed 's/^OVERWRITTEN://' || true)
  skipped_files=$(echo "$result" | tail -n +2 | grep '^SKIPPED:' | sed 's/^SKIPPED://' || true)

  # Count files
  local created_count=0 overwritten_count=0 skipped_count=0

  # Print file lines with symbols
  while IFS= read -r file; do
    [[ -n "$file" ]] && { echo "  + ${file}"; (( ++created_count )); }
  done <<< "$created_files"

  while IFS= read -r file; do
    [[ -n "$file" ]] && { echo "  ! ${file}"; (( ++overwritten_count )); }
  done <<< "$overwritten_files"

  while IFS= read -r file; do
    [[ -n "$file" ]] && { echo "  ~ ${file} (exists, use --force)"; (( ++skipped_count )); }
  done <<< "$skipped_files"

  # Print summary (only when standalone)
  if [[ "$orchestrated" != "true" ]]; then
    echo ""
    echo "$(_vf_init_format_summary "$dry_run" "$created_count" "$overwritten_count" "$skipped_count")"
  fi

  # Print verbose info sections (standalone normal mode only)
  if [[ "$orchestrated" != "true" && "$dry_run" != "true" ]]; then
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
  fi

  # Write result to file if RADP_VF_INIT_RESULT_FILE is set (for caller integration)
  if [[ -n "${RADP_VF_INIT_RESULT_FILE:-}" ]]; then
    {
      echo "$abs_target_dir"
      echo "created:${created_count}"
      echo "skipped:${skipped_count}"
      echo "overwritten:${overwritten_count}"
    } > "$RADP_VF_INIT_RESULT_FILE"
  fi
}

#######################################
# Format summary line for VF init
# Arguments:
#   1 - dry_run flag
#   2 - created count
#   3 - overwritten count
#   4 - skipped count
#######################################
_vf_init_format_summary() {
  local dry_run="$1"
  local created="$2"
  local overwritten="$3"
  local skipped="$4"
  local parts=()

  if (( created > 0 )); then
    local file_word="files"
    (( created == 1 )) && file_word="file"
    if [[ "$dry_run" == "true" ]]; then
      parts+=("${created} ${file_word} to create")
    else
      parts+=("${created} ${file_word} created")
    fi
  fi

  if (( overwritten > 0 )); then
    parts+=("${overwritten} overwritten")
  fi

  if (( skipped > 0 )); then
    parts+=("${skipped} skipped")
  fi

  if (( ${#parts[@]} == 0 )); then
    echo "Nothing to do."
    return
  fi

  local result="${parts[0]}"
  local i
  for (( i=1; i<${#parts[@]}; i++ )); do
    result+=", ${parts[$i]}"
  done
  echo "${result}."
}
