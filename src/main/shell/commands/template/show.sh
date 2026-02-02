#!/usr/bin/env bash
# @cmd
# @desc Show template details and variables
# @arg name! Template name
# @example template show base
# @example template show k8s-cluster

cmd_template_show() {
  local name="${1:-}"

  if [[ -z "$name" ]]; then
    radp_log_error "Template name required"
    return 1
  fi

  _vf_resolve_paths || return 1
  _vf_ruby_template "show" "$name"
}
