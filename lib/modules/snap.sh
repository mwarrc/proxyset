#!/bin/bash
# ProxySet Module - Snap

module_snap_set() {
    local proxy_url="$1"
    if command_exists snap; then
        log "INFO" "Configuring Snap proxy..."
        if check_sudo; then
            sudo snap set system proxy.http="$proxy_url"
            sudo snap set system proxy.https="$proxy_url"
        else
            log "WARN" "Sudo required for snap config. Skipping."
        fi
    fi
}

module_snap_unset() {
    if command_exists snap && check_sudo; then
        log "INFO" "Removing Snap proxy..."
        sudo snap unset system proxy.http
        sudo snap unset system proxy.https
    fi
}

module_snap_status() {
    if command_exists snap; then
        echo "Snap Proxy:"
        snap get system proxy.http || echo "  Not set"
    fi
}
