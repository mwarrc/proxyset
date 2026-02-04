#!/bin/bash
# ProxySet Module - Azure CLI

module_az_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists az; then return 0; fi
    
    log "INFO" "Configuring Azure CLI proxy..."
    
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    
    log "SUCCESS" "Azure CLI proxy configured (uses HTTP_PROXY environment)"
}

module_az_unset() {
    if ! command_exists az; then return 0; fi
    log "INFO" "Azure CLI proxy removed (unset via env module)"
}

module_az_status() {
    if ! command_exists az; then return 0; fi
    echo "Azure CLI Proxy:"
    echo "  HTTP_PROXY: ${HTTP_PROXY:-Not set}"
    echo "  az version: $(az version --output tsv 2>/dev/null | head -1 | awk '{print $2}' || echo 'unknown')"
}
