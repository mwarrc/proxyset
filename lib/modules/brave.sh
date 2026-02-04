#!/bin/bash
# ProxySet Module - Brave Browser (Uses same engine as Chromium)

module_brave_set() {
    # Reuse Chromium logic but different paths if needed. 
    # Brave typically respects Chromium managed policies or env vars.
    if ! command_exists brave-browser; then return 0; fi
    log "INFO" "Configuring Brave Browser..."
    
    # Brave reads /etc/brave/policies/managed/
    local policy_dir="/etc/brave/policies/managed"
    local policy_file="proxyset_proxy.json"
    
    if ! check_sudo; then log "WARN" "Sudo required for Brave policy."; return 1; fi
    
    local proxy_data
    proxy_data=$(parse_proxy_url "$1")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    local proxy_server="${host}:${port}"
    [[ "$proto" == "socks"* ]] && proxy_server="socks5://${host}:${port}"
    
    sudo mkdir -p "$policy_dir"
    cat <<EOF | sudo tee "$policy_dir/$policy_file" > /dev/null
{
  "ProxyMode": "fixed_servers",
  "ProxyServer": "$proxy_server",
  "ProxyBypassList": "$2"
}
EOF
    log "SUCCESS" "Brave managed policy installed"
}

module_brave_unset() {
    if ! command_exists brave-browser; then return 0; fi
    if check_sudo; then
        sudo rm -f "/etc/brave/policies/managed/proxyset_proxy.json"
        log "SUCCESS" "Brave policy removed"
    fi
}

module_brave_status() {
    if ! command_exists brave-browser; then return 0; fi
    echo "Brave:"
    [[ -f "/etc/brave/policies/managed/proxyset_proxy.json" ]] && echo "  Policy: Active" || echo "  Policy: None"
}
