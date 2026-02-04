#!/bin/bash
# bash completion for proxyset

_proxyset() {
    local cur prev opts commands modules
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    commands="set unset wizard status test diagnose run profile snapshot audit pac install update list help"
    
    # Get modules dynamically if possible, otherwise hardcode common ones
    # In a real install, we might source a file or grep the lib dir. 
    # Here we list the known ones.
    modules="apt dnf yum pacman zypper apk xbps brew snap flatpak git npm yarn pip cargo go gem composer docker podman wget curl firefox chromium aws gcloud az systemd all"

    # Profile subcommands
    if [[ "$prev" == "profile" ]]; then
        COMPREPLY=( $(compgen -W "save load list" -- "$cur") )
        return 0
    fi

    # Snapshot subcommands
    if [[ "$prev" == "snapshot" ]]; then
        COMPREPLY=( $(compgen -W "save restore list show diff delete" -- "$cur") )
        return 0
    fi
    
    # First argument: usually a target (module) or a command (if target is omitted/implied 'all' - but syntax is target command)
    # Actually syntax is: proxyset [options] <target|all> <command>
    # OR proxyset <command> (for system commands like wizard, status)
    
    # If the previous word is 'proxyset', we can have a system command OR a module
    if [[ "$prev" == "proxyset" ]]; then
        COMPREPLY=( $(compgen -W "$commands $modules" -- "$cur") )
        return 0
    fi

    # If the previous word is a module, the next must be a command
    if [[ " $modules " =~ " $prev " ]]; then
         COMPREPLY=( $(compgen -W "set unset status test" -- "$cur") )
         return 0
    fi

    # If previous word is 'set' (context: command), we expect args (host)
    # We can't autocomplete hosts easily.
    
    return 0
}

complete -F _proxyset proxyset
