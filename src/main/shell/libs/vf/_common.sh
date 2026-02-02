#!/usr/bin/env bash
# RADP Vagrant Framework - Common helper functions
# Auto-loaded by framework from libs/ directory

# Global variables set by _vf_resolve_paths()
declare -g gr_vf_home=""
declare -g gr_vf_ruby_lib_dir=""

#######################################
# Application version output
# Called by framework for --version global option
# Gets version from Ruby (single source of truth) and uses radp_get_install_version
# to check for .install-version override
#######################################
radp_app_version() {
  local version
  version="$(_vf_get_ruby_version 2>/dev/null)" || version="unknown"
  echo "radp-vf $(radp_get_install_version "$version")"
}

#######################################
# Resolve RADP_VF_HOME and RUBY_LIB_DIR paths
# Detects installation mode (development vs Homebrew)
# Sets global variables: gr_vf_home, gr_vf_ruby_lib_dir
# Returns:
#   0 on success, 1 on failure
#######################################
_vf_resolve_paths() {
  local app_root="${RADP_APP_ROOT:-}"

  if [[ -z "$app_root" ]]; then
    radp_log_error "RADP_APP_ROOT is not set"
    return 1
  fi

  # Use RADP_VF_HOME if set via env var
  if [[ -n "${RADP_VF_HOME:-}" ]]; then
    gr_vf_home="$RADP_VF_HOME"
    # Detect RUBY_LIB_DIR based on directory structure
    if [[ -d "${gr_vf_home}/src/main/ruby/lib/radp_vagrant" ]]; then
      gr_vf_ruby_lib_dir="${gr_vf_home}/src/main/ruby"
    elif [[ -d "${gr_vf_home}/lib/radp_vagrant" ]]; then
      gr_vf_ruby_lib_dir="${gr_vf_home}"
    else
      radp_log_error "Invalid RADP_VF_HOME: ${gr_vf_home}"
      return 1
    fi
    return 0
  fi

  # Auto-detect based on app root
  # Case 1: Development mode - project_root with src/main/ruby
  if [[ -d "${app_root}/src/main/ruby/lib/radp_vagrant" ]]; then
    gr_vf_home="$app_root"
    gr_vf_ruby_lib_dir="${app_root}/src/main/ruby"
  # Case 2: Homebrew/installed mode - libexec with lib/radp_vagrant
  elif [[ -d "${app_root}/lib/radp_vagrant" ]]; then
    gr_vf_home="$app_root"
    gr_vf_ruby_lib_dir="$app_root"
  else
    radp_log_error "Cannot locate RADP Vagrant Framework. Set RADP_VF_HOME."
    return 1
  fi

  export RADP_VF_HOME="$gr_vf_home"
  return 0
}

#######################################
# Check if a config file exists in directory
# Supports: vagrant.yaml, config.yaml, or RADP_VAGRANT_CONFIG_BASE_FILENAME
# Arguments:
#   1 - directory path
# Returns:
#   0 if config file exists, 1 otherwise
#######################################
_vf_has_config_file() {
  local dir="$1"

  # Priority 1: Environment variable
  if [[ -n "${RADP_VAGRANT_CONFIG_BASE_FILENAME:-}" ]]; then
    [[ -f "${dir}/${RADP_VAGRANT_CONFIG_BASE_FILENAME}" ]]
    return
  fi
  # Priority 2: vagrant.yaml (default)
  [[ -f "${dir}/vagrant.yaml" ]] && return 0
  # Priority 3: config.yaml
  [[ -f "${dir}/config.yaml" ]] && return 0
  return 1
}

#######################################
# Resolve config directory
# Priority: -c flag > RADP_VAGRANT_CONFIG_DIR > ./config (if exists)
# Globals:
#   opt_config - config option from CLI parsing
# Arguments:
#   1 - (optional) command name for showing help on failure
# Returns:
#   Config directory path on stdout, 1 on failure
#######################################
_vf_resolve_config_dir() {
  local cmd_name="${1:-}"
  local config_dir=""

  # Priority 1: -c/--config option
  if [[ -n "${opt_config:-}" ]]; then
    config_dir="$opt_config"
  # Priority 2: Environment variable
  elif [[ -n "${RADP_VAGRANT_CONFIG_DIR:-}" ]]; then
    config_dir="$RADP_VAGRANT_CONFIG_DIR"
  # Priority 3: ./config directory if it has config file
  elif [[ -d "./config" ]] && _vf_has_config_file "./config"; then
    config_dir="$(pwd)/config"
  fi

  if [[ -z "$config_dir" ]]; then
    echo "Error: Cannot determine config directory." >&2
    echo "Use -c <dir>, set RADP_VAGRANT_CONFIG_DIR, or run from a directory containing config/vagrant.yaml or config/config.yaml" >&2
    [[ -n "$cmd_name" ]] && { echo >&2; radp_cli_help_command "$cmd_name" >&2; }
    return 1
  fi

  if ! _vf_has_config_file "$config_dir"; then
    echo "Error: No configuration file found in ${config_dir}" >&2
    echo "Expected one of: vagrant.yaml, config.yaml" >&2
    if [[ -n "${RADP_VAGRANT_CONFIG_BASE_FILENAME:-}" ]]; then
      echo "Or the file specified by RADP_VAGRANT_CONFIG_BASE_FILENAME: ${RADP_VAGRANT_CONFIG_BASE_FILENAME}" >&2
    fi
    [[ -n "$cmd_name" ]] && { echo >&2; radp_cli_help_command "$cmd_name" >&2; }
    return 1
  fi

  echo "$config_dir"
}

#######################################
# Get version from Ruby VERSION constant
# This is the single source of truth for version
# Returns:
#   Version string on stdout
#######################################
_vf_get_ruby_version() {
  _vf_resolve_paths || return 1
  (cd "${gr_vf_ruby_lib_dir}" && ruby -r ./lib/radp_vagrant -e "puts RadpVagrant::VERSION" 2>/dev/null)
}

#######################################
# Get version from .install-version file or Ruby VERSION constant
# Returns:
#   Version string on stdout
#######################################
_vf_get_version() {
  _vf_resolve_paths || return 1

  # Check for .install-version file first (written by install.sh for manual installs)
  if [[ -f "${gr_vf_home}/.install-version" ]]; then
    cat "${gr_vf_home}/.install-version"
    return 0
  fi

  # Fall back to Ruby VERSION constant
  _vf_get_ruby_version || echo "unknown"
}
