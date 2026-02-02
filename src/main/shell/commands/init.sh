#!/usr/bin/env bash
# @cmd
# @desc Initialize a new project with sample configuration
# @arg dir Target directory (default: current directory)
# @option -t, --template <name> Use a template (default: base)
# @option --set <var>=<value>~ Set template variable (can be repeated)
# @example init
# @example init myproject
# @example init myproject -t k8s-cluster
# @example init myproject --template k8s-cluster --set cluster_name=homelab --set worker_count=3

cmd_init() {
  _vf_resolve_paths || return 1

  local target_dir="${1:-.}"
  local template="${opt_template:-base}"

  # Create target directory
  mkdir -p "$target_dir"
  local abs_target_dir
  abs_target_dir="$(cd "$target_dir" && pwd)"
  local abs_config_dir="${abs_target_dir}/config"

  # Check if config already exists
  if _vf_has_config_file "$abs_config_dir"; then
    radp_log_error "Configuration already exists in ${abs_config_dir}"
    return 1
  fi

  echo "Initializing RADP Vagrant Framework project..."
  echo "Template: ${template}"
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

  # Call Ruby renderer
  local result
  result=$(_vf_ruby_init "$template" "$abs_target_dir" "$vars_json") || true

  # Parse result
  local status
  status=$(echo "$result" | head -n1)

  if [[ "$status" != "SUCCESS" ]]; then
    local error_msg
    error_msg=$(echo "$result" | tail -n +2)
    radp_log_error "$error_msg"
    return 1
  fi

  # Get list of created files
  local files
  files=$(echo "$result" | tail -n +2)

  echo "Project initialized successfully!"
  echo ""
  echo "Created in ${abs_target_dir}/:"
  echo "$files" | while read -r file; do
    [[ -n "$file" ]] && echo "  - ${file}"
  done
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
  echo "  radp-vf -c ${abs_config_dir} vg status"
  echo ""
  echo "Edit the config file (vagrant.yaml or config.yaml) to change 'env' and create your own environment file."
  echo "Add custom provisions in provisions/definitions/ with user: prefix."
  echo ""
  echo "Use 'radp-vf template list' to see all available templates."
}
