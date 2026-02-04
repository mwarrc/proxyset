#!/bin/bash
# ProxySet Module - MATE Desktop
# MATE allows GSettings configuration similar to GNOME

module_mate_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists gsettings; then return 0; fi
    # Check if mate schema exists
    if ! gsettings list-schemas | grep -q "org.mate.system.proxy"; then return 0; fi
    
    log "INFO" "Configuring MATE Desktop proxy..."
    
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    gsettings set org.mate.system.proxy mode 'manual'
    gsettings set org.mate.system.proxy.http host "$host"
    gsettings set org.mate.system.proxy.http port "$port"
    gsettings set org.mate.system.proxy.https host "$host"
    gsettings set org.mate.system.proxy.https port "$port"
    
    if [[ -n "$user" ]]; then
         gsettings set org.mate.system.proxy.http authentication-user "$user"
         gsettings set org.mate.system.proxy.http authentication-password "$pass"
    fi
    
    if [[ -n "$no_proxy" ]]; then
         # Format needs to be list ['localhost', ...]
         # Simplified for now
         true 
    fi
    
    log "SUCCESS" "MATE proxy settings applied"
}

module_mate_unset() {
    if ! command_exists gsettings; then return 0; fi
    if gsettings list-schemas | grep -q "org.mate.system.proxy"; then
        gsettings set org.mate.system.proxy mode 'none'
        log "SUCCESS" "MATE proxy disabled"
    fi
}

module_mate_status() {
    if ! command_exists gsettings; then return 0; fi
    if gsettings list-schemas | grep -q "org.mate.system.proxy"; then
         local mode
         mode=$(gsettings get org.mate.system.proxy mode)
         echo "MATE Desktop: $mode"
    fi
}
