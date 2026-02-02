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

  case "$shell" in
  bash)
    # Generate base completion and add delegation support
    radp_cli_completion_generate "$shell" | _completion_add_delegation_support
    ;;
  zsh)
    radp_cli_completion_generate "$shell"
    ;;
  *)
    radp_log_error "Unsupported shell: $shell (supported: bash, zsh)"
    return 1
    ;;
  esac
}

#######################################
# Add delegation support to bash completion script
# Allows other completions (e.g., homelabctl vf) to delegate to _radp_vf
#######################################
_completion_add_delegation_support() {
  # Replace the initialization block to support delegation
  sed '
    # Match the initialization block and replace it
    /^    # 兼容模式：如果 _init_completion 不存在，使用手动初始化$/,/^    fi$/ {
      /^    # 兼容模式：如果 _init_completion 不存在，使用手动初始化$/ {
        N;N;N;N;N;N;N;N;N
        c\
    # Support delegation from other completion functions (e.g., homelabctl vf)\
    # When _RADP_VF_DELEGATED is set, skip _init_completion and use pre-set COMP_* variables\
    if [[ -z "${_RADP_VF_DELEGATED:-}" ]]; then\
        # Direct invocation: use _init_completion if available\
        if type _init_completion \&>/dev/null; then\
            _init_completion || return\
        else\
            COMPREPLY=()\
            cur="${COMP_WORDS[COMP_CWORD]}"\
            prev="${COMP_WORDS[COMP_CWORD-1]}"\
            words=("${COMP_WORDS[@]}")\
            cword="$COMP_CWORD"\
        fi\
    else\
        # Delegated invocation: use pre-set COMP_* variables\
        COMPREPLY=()\
        cur="${COMP_WORDS[COMP_CWORD]}"\
        prev="${COMP_WORDS[COMP_CWORD-1]}"\
        words=("${COMP_WORDS[@]}")\
        cword="$COMP_CWORD"\
    fi
      }
    }
  '
}
