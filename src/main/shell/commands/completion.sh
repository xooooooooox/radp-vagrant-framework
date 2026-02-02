#!/usr/bin/env bash
# @cmd
# @desc Generate shell completion script
# @arg shell! Shell type: bash or zsh
# @example completion bash
# @example completion zsh
# @example completion bash >> ~/.bashrc
# @example completion zsh > ~/.zfunc/_radp-vf

cmd_completion() {
  local shell="${1:-}"

  if [[ -z "$shell" ]]; then
    radp_log_error "Shell type required (bash or zsh)"
    return 1
  fi

  radp_cli_completion_generate "${shell}"
}
