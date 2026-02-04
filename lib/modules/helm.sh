#!/bin/bash
# ProxySet Module - Helm

module_helm_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    if ! command_exists helm; then return 0; fi
    log "INFO" "Configuring Helm proxy (env)..."
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    log "SUCCESS" "Helm configured via environment variables"
}

module_helm_unset() {
    if ! command_exists helm; then return 0; fi
    unset HTTP_PROXY HTTPS_PROXY NO_PROXY
    log "SUCCESS" "Helm proxy (env) unset"
}

module_helm_status() {
    if ! command_exists helm; then return 0; fi
    echo "Helm:"
    echo "  HTTPS_PROXY: ${HTTPS_PROXY:-Not set}"
}
