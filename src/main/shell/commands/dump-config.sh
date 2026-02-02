#!/usr/bin/env bash
# @cmd
# @desc Dump merged configuration (use -o for file output)
# @arg filter Guest ID or machine name filter
# @option -f, --format <type> Output format: json or yaml (default: json)
# @option -o, --output <file> Output file path
# @option -c, --config <dir> Configuration directory
# @option -e, --env <name> Override environment name
# @example dump-config
# @example dump-config -f yaml
# @example dump-config -o config.json
# @example dump-config -f yaml -o config.yaml
# @example dump-config node-1

cmd_dump_config() {
  _vf_resolve_paths || return 1

  local config_dir
  config_dir="$(_vf_resolve_config_dir "dump-config")" || return 1

  local format="${opt_format:-json}"
  local output="${opt_output:-}"

  # Validate format
  if [[ "$format" != "json" && "$format" != "yaml" ]]; then
    radp_log_error "Invalid format '$format'. Use 'json' or 'yaml'."
    return 1
  fi

  # Convert relative output path to absolute before Ruby changes directory
  if [[ -n "$output" && "$output" != /* ]]; then
    output="$(pwd)/${output}"
  fi

  _vf_ruby_dump_config "$config_dir" "${opt_env:-}" "${1:-}" "$format" "$output"
}
