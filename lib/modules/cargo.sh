#!/bin/bash
# ProxySet Module - Cargo (Rust)

module_cargo_set() {
    local proxy_url="$1"
    local config_file="$HOME/.cargo/config.toml"
    
    log "INFO" "Configuring Cargo proxy in $config_file..."
    mkdir -p "$(dirname "$config_file")"
    
    # Remove existing [http] section if ProxySet managed
    sed -i '/# ProxySet Start/,/# ProxySet End/d' "$config_file" 2>/dev/null || touch "$config_file"
    
    cat >> "$config_file" <<EOF
# ProxySet Start
[http]
proxy = "$proxy_url"
check-revoke = false
# ProxySet End
EOF
    log "SUCCESS" "Cargo proxy configured."
}

module_cargo_unset() {
    local config_file="$HOME/.cargo/config.toml"
    if [[ -f "$config_file" ]]; then
        log "INFO" "Removing Cargo proxy settings..."
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$config_file"
    fi
}

module_cargo_status() {
    local config_file="$HOME/.cargo/config.toml"
    if [[ -f "$config_file" ]]; then
        echo "Cargo Proxy Settings:"
        grep -A 3 "ProxySet Start" "$config_file" || echo "  None set"
    fi
}
