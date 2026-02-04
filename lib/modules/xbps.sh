#!/bin/bash
# ProxySet Module - Void Linux XBPS

module_xbps_set() {
    local proxy_url="$1"
    
    if ! command_exists xbps-install; then return 0; fi
    
    log "INFO" "Configuring XBPS proxy..."
    
    if ! check_sudo; then
        log "WARN" "Sudo required for XBPS. Skipping."
        return 1
    fi
    
    local xbps_conf="/etc/xbps.d/10-proxy.conf"
    echo "http_proxy=\"$proxy_url\"" | sudo tee "$xbps_conf" > /dev/null
    
    log "SUCCESS" "XBPS proxy configured"
}

module_xbps_unset() {
    if ! command_exists xbps-install; then return 0; fi
    
    log "INFO" "Removing XBPS proxy..."
    
    if check_sudo; then
        sudo rm -f /etc/xbps.d/10-proxy.conf
    fi
}

module_xbps_status() {
    if ! command_exists xbps-install; then return 0; fi
    
    echo "XBPS Proxy:"
    if [[ -f /etc/xbps.d/10-proxy.conf ]]; then
        cat /etc/xbps.d/10-proxy.conf
    else
        echo "  Not configured"
    fi
}
