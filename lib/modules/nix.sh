#!/bin/bash
# ProxySet Module - Nix Package Manager

readonly NIX_CONF="/etc/nix/nix.conf"

module_nix_set() {
    local proxy_url="$1"
    # Nix typically needs daemon restart, so we might just warn
    if ! command_exists nix-env; then return 0; fi
    
    log "INFO" "Configuring Nix..."
    if ! check_sudo; then log "WARN" "Sudo required for Nix config."; return 1; fi
    
    # We should add proxy to nix.conf? Nix uses http_proxy env mainly for daemon.
    # But usually configured in service override.
    # Let's verify if we can edit conf.
    if [[ -f "$NIX_CONF" ]]; then
       # Nix doesn't have a simple proxy key in conf, usually relies on env vars provided to the daemon.
       # Setting user environment is best effort.
       export http_proxy="$proxy_url"
       export https_proxy="$proxy_url"
       export NIX_REMOTE_PROXY="$proxy_url"
       log "SUCCESS" "Nix environment variables set (Ensure your nix-daemon sees these)"
    fi
}

module_nix_unset() {
    if ! command_exists nix-env; then return 0; fi
    unset http_proxy https_proxy NIX_REMOTE_PROXY
}

module_nix_status() {
    if ! command_exists nix-env; then return 0; fi
    echo "Nix:"
    echo "  http_proxy: ${http_proxy:-Not set}"
    echo "  See also: /etc/systemd/system/nix-daemon.service.d/override.conf (if using daemon)"
}
