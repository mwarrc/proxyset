#!/bin/bash
# ProxySet Module - aria2

readonly ARIA2_CONF="$HOME/.aria2/aria2.conf"

module_aria2_set() {
    local proxy_url="$1"
    if ! command_exists aria2c; then return 0; fi
    
    log "INFO" "Configuring aria2..."
    mkdir -p "$(dirname "$ARIA2_CONF")"
    
    # Check if config exists, create if not
    touch "$ARIA2_CONF"
    
    # Remove existing proxy lines
    sed -i '/^http-proxy=/d' "$ARIA2_CONF"
    sed -i '/^https-proxy=/d' "$ARIA2_CONF"
    sed -i '/^ftp-proxy=/d' "$ARIA2_CONF"
    sed -i '/^all-proxy=/d' "$ARIA2_CONF"
    
    {
        echo "http-proxy=$proxy_url"
        echo "https-proxy=$proxy_url"
        echo "ftp-proxy=$proxy_url"
    } >> "$ARIA2_CONF"
    
    log "SUCCESS" "aria2 configured in $ARIA2_CONF"
}

module_aria2_unset() {
    if ! command_exists aria2c; then return 0; fi
    if [[ -f "$ARIA2_CONF" ]]; then
        sed -i '/^http-proxy=/d' "$ARIA2_CONF"
        sed -i '/^https-proxy=/d' "$ARIA2_CONF"
        sed -i '/^ftp-proxy=/d' "$ARIA2_CONF"
        log "SUCCESS" "aria2 proxy configurations removed"
    fi
}

module_aria2_status() {
    if ! command_exists aria2c; then return 0; fi
    echo "aria2:"
    [[ -f "$ARIA2_CONF" ]] && grep "proxy=" "$ARIA2_CONF" || echo "  Not configured"
}
