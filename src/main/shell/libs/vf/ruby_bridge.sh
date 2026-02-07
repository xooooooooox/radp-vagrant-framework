#!/usr/bin/env bash
# RADP Vagrant Framework - Ruby CLI bridge functions
# Auto-loaded by framework from libs/ directory
# Provides wrapper functions for calling Ruby CLI commands

#######################################
# Call Ruby CLI::Info command
# Arguments:
#   1 - config_dir (can be empty)
#   2 - env_override (can be empty)
#######################################
_vf_ruby_info() {
  local config_dir="${1:-}"
  local env_override="${2:-}"

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::Info.new(
      '${config_dir}'.empty? ? nil : '${config_dir}',
      env_override: '${env_override}'.empty? ? nil : '${env_override}',
      radp_vf_home: '${gr_vf_home}',
      ruby_lib_dir: '${gr_vf_ruby_lib_dir}'
    )
    exit cmd.execute
  "
}

#######################################
# Call Ruby CLI::List command
# Arguments:
#   1 - config_dir
#   2 - env_override
#   3 - verbose (true/false)
#   4 - show_provisions (true/false)
#   5 - show_synced_folders (true/false)
#   6 - show_triggers (true/false)
#   7 - filter (can be empty)
#######################################
_vf_ruby_list() {
  local config_dir="$1"
  local env_override="${2:-}"
  local verbose="${3:-false}"
  local show_provisions="${4:-false}"
  local show_synced_folders="${5:-false}"
  local show_triggers="${6:-false}"
  local filter="${7:-}"

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::List.new(
      '${config_dir}',
      env_override: '${env_override}'.empty? ? nil : '${env_override}',
      verbose: ${verbose},
      show_provisions: ${show_provisions},
      show_synced_folders: ${show_synced_folders},
      show_triggers: ${show_triggers},
      filter: '${filter}'.empty? ? nil : '${filter}'
    )
    exit cmd.execute
  "
}

#######################################
# Call Ruby CLI::Validate command
# Arguments:
#   1 - config_dir
#   2 - env_override
#######################################
_vf_ruby_validate() {
  local config_dir="$1"
  local env_override="${2:-}"

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::Validate.new(
      '${config_dir}',
      env_override: '${env_override}'.empty? ? nil : '${env_override}'
    )
    exit cmd.execute
  "
}

#######################################
# Call Ruby CLI::DumpConfig command
# Arguments:
#   1 - config_dir
#   2 - env_override
#   3 - filter
#   4 - format (json/yaml)
#   5 - output file (can be empty)
#######################################
_vf_ruby_dump_config() {
  local config_dir="$1"
  local env_override="${2:-}"
  local filter="${3:-}"
  local format="${4:-json}"
  local output="${5:-}"

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::DumpConfig.new(
      '${config_dir}',
      env_override: '${env_override}'.empty? ? nil : '${env_override}',
      filter: '${filter}'.empty? ? nil : '${filter}',
      format: :${format},
      output: '${output}'.empty? ? nil : '${output}'
    )
    exit cmd.execute
  "
}

#######################################
# Call Ruby CLI::Generate command
# Arguments:
#   1 - config_dir
#   2 - env_override
#   3 - output file (can be empty)
#######################################
_vf_ruby_generate() {
  local config_dir="$1"
  local env_override="${2:-}"
  local output="${3:-}"

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::Generate.new(
      '${config_dir}',
      env_override: '${env_override}'.empty? ? nil : '${env_override}',
      output: '${output}'.empty? ? nil : '${output}'
    )
    exit cmd.execute
  "
}

#######################################
# Call Ruby CLI::Template command
# Arguments:
#   1 - subcommand (list/show)
#   2+ - additional arguments
#######################################
_vf_ruby_template() {
  local subcommand="${1:-list}"
  shift || true

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::Template.new('${subcommand}', ARGV)
    exit cmd.execute
  " -- "$@"
}

#######################################
# Call Ruby template renderer for init command
# Arguments:
#   1 - template name
#   2 - target directory (absolute path)
#   3 - variables JSON string
#   4 - dry_run (true/false)
#   5 - force (true/false)
# Returns:
#   SUCCESS on first line if successful, followed by created files
#   SKIPPED:<file> for files skipped due to existing
#   ERROR on first line if failed, followed by error message
#######################################
_vf_ruby_init() {
  local template="$1"
  local target_dir="$2"
  local vars_json="$3"
  local dry_run="${4:-false}"
  local force="${5:-false}"

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -r json -e "
    require_relative 'lib/radp_vagrant/templates/renderer'

    template_name = '${template}'
    target_dir = '${target_dir}'
    variables = JSON.parse('${vars_json}')
    dry_run = ${dry_run}
    force = ${force}

    renderer = RadpVagrant::Templates::Renderer.new(template_name, variables)
    result = renderer.render_to(target_dir, dry_run: dry_run, force: force)

    if result[:success]
      puts 'SUCCESS'
      (result[:files] || []).each { |f| puts f }
      (result[:overwritten] || []).each { |f| puts \"OVERWRITTEN:#{f}\" }
      (result[:skipped] || []).each { |f| puts \"SKIPPED:#{f}\" }
    else
      puts 'ERROR'
      puts result[:error]
    end
  " 2>&1
}

#######################################
# Call Ruby CLI::Resolve command
# Resolves cluster names and guest IDs to machine names
# Arguments:
#   1 - config_dir
#   2 - env_override (can be empty)
#   remaining args: --cluster=xxx --guest-ids=xxx
# Output:
#   One machine name per line
#######################################
_vf_ruby_resolve() {
  local config_dir="$1"
  local env_override="$2"
  shift 2

  # Parse cluster and guest-ids arguments
  local clusters=()
  local guest_ids=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cluster=*) clusters+=("${1#*=}") ;;
      --guest-ids=*) IFS=',' read -ra guest_ids <<< "${1#*=}" ;;
    esac
    shift
  done

  local clusters_ruby
  if [[ ${#clusters[@]} -gt 0 ]]; then
    clusters_ruby=$(printf "'%s'," "${clusters[@]}")
    clusters_ruby="[${clusters_ruby%,}]"
  else
    clusters_ruby="[]"
  fi

  local guest_ids_ruby
  if [[ ${#guest_ids[@]} -gt 0 ]]; then
    guest_ids_ruby=$(printf "'%s'," "${guest_ids[@]}")
    guest_ids_ruby="[${guest_ids_ruby%,}]"
  else
    guest_ids_ruby="[]"
  fi

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::Resolve.new(
      '${config_dir}',
      env_override: '${env_override}'.empty? ? nil : '${env_override}',
      clusters: ${clusters_ruby},
      guest_ids: ${guest_ids_ruby}
    )
    cmd.execute
  " 2>/dev/null
}

#######################################
# Call Ruby CLI::Completion command
# Provides completion data for shell completion
# Arguments:
#   1 - config_dir
#   2 - env_override (can be empty)
#   3 - type (machines/clusters/guests)
#   4 - cluster (required for type=guests, can be empty otherwise)
# Output:
#   One item per line
#######################################
_vf_ruby_completion() {
  local config_dir="$1"
  local env_override="${2:-}"
  local type="${3:-machines}"
  local cluster="${4:-}"

  cd "${gr_vf_ruby_lib_dir}" || return 1
  ruby -r ./lib/radp_vagrant -e "
    cmd = RadpVagrant::CLI::Completion.new(
      '${config_dir}',
      env_override: '${env_override}'.empty? ? nil : '${env_override}',
      type: '${type}',
      cluster: '${cluster}'.empty? ? nil : '${cluster}'
    )
    cmd.execute
  " 2>/dev/null
}
