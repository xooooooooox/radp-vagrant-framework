#compdef radp-vf
# Zsh completion for radp-vf
# Install: copy to ~/.zfunc/_radp-vf and add "fpath=(~/.zfunc $fpath)" to ~/.zshrc

_radp_vf() {
    local -a commands
    local -a global_opts
    local -a vagrant_cmds
    local -a template_cmds
    local -a shell_types

    commands=(
        'init:Initialize a new project with sample configuration'
        'vg:Run vagrant command with framework'
        'list:List clusters and guests from configuration'
        'dump-config:Dump merged configuration'
        'generate:Generate standalone Vagrantfile'
        'validate:Validate YAML configuration files'
        'info:Show environment and configuration info'
        'template:Manage project templates'
        'completion:Generate shell completion script'
        'version:Show version'
        'help:Show help'
    )

    global_opts=(
        '-c[Configuration directory]:config dir:_files -/'
        '--config[Configuration directory]:config dir:_files -/'
        '-e[Override environment]:environment name:'
        '--env[Override environment]:environment name:'
        '-h[Show help]'
        '--help[Show help]'
        '-v[Enable verbose output]'
        '--verbose[Enable verbose output]'
        '--version[Show version]'
    )

    vagrant_cmds=(
        'status:Show VM status'
        'up:Start and provision VMs'
        'halt:Stop VMs'
        'destroy:Destroy VMs'
        'reload:Restart VMs'
        'provision:Run provisioners'
        'ssh:SSH into a VM'
        'ssh-config:Show SSH config'
        'validate:Validate Vagrantfile'
        'box:Manage boxes'
        'snapshot:Manage snapshots'
        'plugin:Manage plugins'
    )

    template_cmds=(
        'list:List available templates'
        'show:Show template details'
    )

    shell_types=(
        'bash:Generate Bash completion script'
        'zsh:Generate Zsh completion script'
    )

    dump_config_opts=(
        '-f[Output format]:format:(json yaml)'
        '--format[Output format]:format:(json yaml)'
        '-o[Output file]:output file:_files'
        '--output[Output file]:output file:_files'
    )

    list_opts=(
        '-v[Show detailed info]'
        '--verbose[Show detailed info]'
        '--provisions[Show provisions only]'
        '--synced-folders[Show synced folders only]'
        '--triggers[Show triggers only]'
    )

    init_opts=(
        '-t[Use a template]:template name:'
        '--template[Use a template]:template name:'
        '--set[Set template variable]:var=value:'
    )

    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        $global_opts \
        '1: :->command' \
        '*: :->args'

    case $state in
        command)
            _describe -t commands 'radp-vf command' commands
            ;;
        args)
            case $line[1] in
                vg)
                    if [[ $CURRENT -eq 3 ]]; then
                        _describe -t vagrant-commands 'vagrant command' vagrant_cmds
                    fi
                    ;;
                init)
                    _arguments $init_opts '*:directory:_files -/'
                    ;;
                dump-config)
                    _arguments $dump_config_opts '*:filter:'
                    ;;
                generate)
                    _files
                    ;;
                list)
                    _arguments $list_opts '*:filter:'
                    ;;
                template)
                    if [[ $CURRENT -eq 3 ]]; then
                        _describe -t template-commands 'template subcommand' template_cmds
                    fi
                    ;;
                completion)
                    if [[ $CURRENT -eq 3 ]]; then
                        _describe -t shell-types 'shell type' shell_types
                    fi
                    ;;
                validate|info|version|help)
                    # No additional arguments
                    ;;
            esac
            ;;
    esac
}

_radp_vf "$@"
