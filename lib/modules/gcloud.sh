#!/bin/bash
# ProxySet Module - Google Cloud CLI

module_gcloud_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists gcloud; then return 0; fi
    
    log "INFO" "Configuring Google Cloud CLI proxy..."
    
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    
    log "SUCCESS" "gcloud proxy configured (uses HTTP_PROXY environment)"
}

module_gcloud_unset() {
    if ! command_exists gcloud; then return 0; fi
    log "INFO" "gcloud proxy removed (unset via env module)"
}

module_gcloud_status() {
    if ! command_exists gcloud; then return 0; fi
    echo "Google Cloud CLI Proxy:"
    echo "  HTTP_PROXY: ${HTTP_PROXY:-Not set}"
    echo "  gcloud version: $(gcloud version --format='value(version)' 2>/dev/null || echo 'unknown')"
}
