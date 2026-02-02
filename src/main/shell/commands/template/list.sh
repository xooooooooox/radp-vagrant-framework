#!/usr/bin/env bash
# @cmd
# @desc List available project templates
# @example template list

cmd_template_list() {
  _vf_resolve_paths || return 1
  _vf_ruby_template "list"
}
