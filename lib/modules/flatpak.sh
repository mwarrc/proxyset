#!/bin/bash
# ProxySet Module - Flatpak

module_flatpak_set() {
    local proxy_url="$1"
    if command_exists flatpak; then
        log "INFO" "Configuring Flatpak proxy (via environment)..."
        # Flatpak usually respects the session env vars, but we can set global overrides
        if check_sudo; then
            sudo flatpak override --global --env=http_proxy="$proxy_url"
            sudo flatpak override --global --env=https_proxy="$proxy_url"
        else
            log "WARN" "Sudo required for flatpak override. Skipping."
        fi
    fi
}

module_flatpak_unset() {
    if command_exists flatpak && check_sudo; then
        log "INFO" "Removing Flatpak overrides..."
        sudo flatpak override --global --unset-env=http_proxy
        sudo flatpak override --global --unset-env=https_proxy
    fi
}

module_flatpak_status() {
    if command_exists flatpak; then
        echo "Flatpak Overrides:"
        flatpak override --global | grep -E "(http_proxy|https_proxy)" || echo "  None set"
    fi
}
