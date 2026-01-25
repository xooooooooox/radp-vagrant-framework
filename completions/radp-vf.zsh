#compdef radp-vf
# Zsh completion for radp-vf
# Install: copy to ~/.zfunc/_radp-vf and add "fpath=(~/.zfunc $fpath)" to ~/.zshrc

_radp_vf() {
    local -a commands
    local -a global_opts
    local -a vagrant_cmds
    local -a dump_config_opts
    local -a format_values

    commands=(
        'init:Initialize a new project with sample configuration'
        'vg:Run vagrant command with framework'
        'list:List clusters and guests from configuration'
        'dump-config:Dump merged configuration'
        'generate:Generate standalone Vagrantfile'
        'validate:Validate YAML configuration files'
        'info:Show environment and configuration info'
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
        '-v[Show version]'
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

    dump_config_opts=(
        '-f[Output format]:format:(json yaml)'
        '--format[Output format]:format:(json yaml)'
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
                    _files -/
                    ;;
                dump-config)
                    _arguments $dump_config_opts '*:filter:'
                    ;;
                generate)
                    _files
                    ;;
                list|validate|info|version|help)
                    # No additional arguments
                    ;;
            esac
            ;;
    esac
}

_radp_vf "$@"
