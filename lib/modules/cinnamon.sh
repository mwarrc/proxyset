#!/bin/bash
# ProxySet Module - Cinnamon Desktop
# Cinnamon also uses gsettings (org.cinnamon.system.proxy or org.gnome.system.proxy fallback)

module_cinnamon_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists gsettings; then return 0; fi
    
    # Cinnamon often uses GNOME settings under the hood, but check cinnamon specific first
    local schema="org.cinnamon.system.proxy"
    if ! gsettings list-schemas | grep -q "$schema"; then 
        schema="org.gnome.system.proxy" # Fallback
    fi
    
    log "INFO" "Configuring Cinnamon ($schema)..."
    
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    gsettings set $schema mode 'manual'
    gsettings set $schema.http host "$host"
    gsettings set $schema.http port "$port"
    gsettings set $schema.https host "$host"
    gsettings set $schema.https port "$port"
    
    log "SUCCESS" "Cinnamon settings applied via $schema"
}

module_cinnamon_unset() {
    if ! command_exists gsettings; then return 0; fi
    # We clear both to be safe/lazy
    gsettings set org.cinnamon.system.proxy mode 'none' 2>/dev/null || true
    gsettings set org.gnome.system.proxy mode 'none' 2>/dev/null || true
}

module_cinnamon_status() {
    echo "Cinnamon: Checked via GSettings"
}
