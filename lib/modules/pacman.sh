#!/bin/bash
# ProxySet Module - Pacman (Arch Linux)

module_pacman_set() {
    local proxy_url="$1"
    if command_exists pacman; then
        log "INFO" "Configuring Pacman proxy via environment variables..."
        # Pacman uses the standard http_proxy environment variables
        # We handle this in the env module, but for Arch, users often use 
        # XferCommand in pacman.conf which might need separate handling if custom.
        log "DEBUG" "Pacman typically follows system environment variables."
    fi
}

module_pacman_unset() {
    : # Standard env unset covers pacman usually
}

module_pacman_status() {
    if command_exists pacman; then
        echo "Pacman:"
        echo "  Usage: Follows system environment variables (http_proxy)."
    fi
}
