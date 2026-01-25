# Bash completion for radp-vf
# Install: source this file or copy to ~/.local/share/bash-completion/completions/radp-vf

_radp_vf() {
    local cur prev words cword

    # Compatible mode: manual init if _init_completion not available
    if type _init_completion &>/dev/null; then
        _init_completion || return
    else
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="$COMP_CWORD"
    fi

    local commands="init vg list dump-config generate validate info version help"
    local global_opts="-c --config -e --env -h --help -v --version"

    # Find the command position (skip global options)
    local cmd_pos=1
    local cmd=""
    while [[ $cmd_pos -lt $cword ]]; do
        case "${words[$cmd_pos]}" in
            -c|--config|-e|--env)
                ((cmd_pos += 2))
                ;;
            -*)
                ((cmd_pos++))
                ;;
            *)
                cmd="${words[$cmd_pos]}"
                break
                ;;
        esac
    done

    # Complete global options before command
    if [[ -z "$cmd" ]]; then
        case "$cur" in
            -*)
                COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
                return
                ;;
        esac

        # After -c/--config, complete directories
        if [[ "$prev" == "-c" || "$prev" == "--config" ]]; then
            COMPREPLY=($(compgen -d -- "$cur"))
            return
        fi

        # After -e/--env, no completion (user provides env name)
        if [[ "$prev" == "-e" || "$prev" == "--env" ]]; then
            return
        fi

        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return
    fi

    # Command-specific completions
    case "$cmd" in
        vg)
            # Vagrant subcommands
            local vagrant_cmds="status up halt destroy reload provision ssh ssh-config validate box snapshot plugin"
            if [[ $cword -eq $((cmd_pos + 1)) ]]; then
                COMPREPLY=($(compgen -W "$vagrant_cmds" -- "$cur"))
            fi
            ;;
        init)
            # Directory completion
            COMPREPLY=($(compgen -d -- "$cur"))
            ;;
        dump-config)
            # dump-config options and filter argument
            case "$cur" in
                -*)
                    COMPREPLY=($(compgen -W "-f --format" -- "$cur"))
                    ;;
            esac
            if [[ "$prev" == "-f" || "$prev" == "--format" ]]; then
                COMPREPLY=($(compgen -W "json yaml" -- "$cur"))
            fi
            ;;
        generate)
            # Output file completion
            COMPREPLY=($(compgen -f -- "$cur"))
            ;;
        list|validate|info|version|help)
            # No additional arguments
            ;;
    esac
}

complete -F _radp_vf radp-vf
