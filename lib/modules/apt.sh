#!/bin/bash
# ProxySet Module - APT

module_apt_set() {
    local proxy_url="$1"
    local type=$(echo "$proxy_url" | cut -d: -f1)
    
    if command_exists apt; then
        log "INFO" "Configuring APT proxy (Protocol: $type)..."
        local apt_conf="/etc/apt/apt.conf.d/95proxies"
        
        # APT usually needs http:// or https://. For SOCKS, some setups use socks5h://
        local content="Acquire::http::Proxy \"$proxy_url\";
Acquire::https::Proxy \"$proxy_url\";"
        
        if [[ "$type" == "socks5" || "$type" == "socks4" ]]; then
            log "WARN" "APT support for SOCKS is limited. Ensure apt-transport-https or similar is installed."
        fi
        
        if check_sudo; then
            echo "$content" | sudo tee "$apt_conf" > /dev/null
        else
            log "WARN" "Sudo required to configure APT. Skipping."
        fi
    fi
}

module_apt_unset() {
    if command_exists apt; then
        local apt_conf="/etc/apt/apt.conf.d/95proxies"
        if [[ -f "$apt_conf" ]]; then
            log "INFO" "Removing APT proxy..."
            if check_sudo; then
                sudo rm "$apt_conf"
            else
                log "WARN" "Sudo required to remove APT proxy. Skipping."
            fi
        fi
    fi
}

module_apt_status() {
    if command_exists apt; then
        echo "APT Proxy:"
        local apt_conf="/etc/apt/apt.conf.d/95proxies"
        if [[ -f "$apt_conf" ]]; then
            cat "$apt_conf"
        else
            echo "  Not set"
        fi
    fi
}
