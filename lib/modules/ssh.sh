#!/bin/bash
# ProxySet Module - SSH

module_ssh_set() {
    local proxy_url="$1"
    local config_file="$HOME/.ssh/config"
    
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r type user pass host port <<< "$proxy_data"

    log "INFO" "Configuring SSH proxy (Type: $type, Host: $host, Port: $port)..."
    mkdir -p "$(dirname "$config_file")"
    
    local proxy_cmd
    case "$type" in
        socks5) proxy_cmd="nc -X 5 -x $host:$port %h %p" ;;
        socks4) proxy_cmd="nc -X 4 -x $host:$port %h %p" ;;
        *)      proxy_cmd="nc -X connect -x $host:$port %h %p" ;;
    esac

    # We'll use corkscrew (for HTTP) or nc (for SOCKS) if available
    cat >> "$config_file" <<EOF

# ProxySet Start
Host *
    ProxyCommand $proxy_cmd
# ProxySet End
EOF
    log "SUCCESS" "SSH ProxyCommand configured."
}

module_ssh_unset() {
    local config_file="$HOME/.ssh/config"
    if [[ -f "$config_file" ]]; then
        log "INFO" "Removing SSH proxy settings..."
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$config_file"
    fi
}

module_ssh_status() {
    local config_file="$HOME/.ssh/config"
    if [[ -f "$config_file" ]]; then
        echo "SSH Proxy Settings:"
        grep -A 2 "ProxySet Start" "$config_file" || echo "  None set"
    fi
}
