#!/usr/bin/env bash
# @cmd
# @desc Generate standalone Vagrantfile
# @arg output Output file path
# @example generate
# @example generate Vagrantfile.standalone
# @example generate -c ./config Vagrantfile.standalone

cmd_generate() {
  _vf_resolve_paths || return 1

  local config_dir
  config_dir="$(_vf_resolve_config_dir "generate")" || return 1

  local output="${1:-}"

  # Convert relative output path to absolute before Ruby changes directory
  if [[ -n "$output" && "$output" != /* ]]; then
    output="$(pwd)/${output}"
  fi

_vf_ruby_generate "$config_dir" "${gopt_env:-}" "$output"
}
