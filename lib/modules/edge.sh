#!/bin/bash
# ProxySet Module - Microsoft Edge

module_edge_set() {
    if ! command_exists microsoft-edge; then return 0; fi
    log "INFO" "Configuring Microsoft Edge..."
    
    local policy_dir="/etc/opt/edge/policies/managed"
    local policy_file="proxyset_proxy.json"
    
    if ! check_sudo; then log "WARN" "Sudo required."; return 1; fi
    
    # Logic similar to Chromium
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
    log "SUCCESS" "Edge managed policy installed"
}

module_edge_unset() {
    if ! command_exists microsoft-edge; then return 0; fi
    if check_sudo; then
        sudo rm -f "/etc/opt/edge/policies/managed/proxyset_proxy.json"
        log "SUCCESS" "Edge policy removed"
    fi
}

module_edge_status() {
    if ! command_exists microsoft-edge; then return 0; fi
    echo "Microsoft Edge:"
    [[ -f "/etc/opt/edge/policies/managed/proxyset_proxy.json" ]] && echo "  Policy: Active" || echo "  Policy: None"
}
