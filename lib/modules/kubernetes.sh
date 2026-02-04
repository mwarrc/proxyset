#!/bin/bash
# ProxySet Module - Kubernetes (kubectl)

module_kubernetes_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    if ! command_exists kubectl; then return 0; fi
    log "INFO" "Configuring kubectl proxy (env)..."
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    log "SUCCESS" "kubectl configured via environment variables"
}

module_kubernetes_unset() {
    if ! command_exists kubectl; then return 0; fi
    unset HTTP_PROXY HTTPS_PROXY NO_PROXY
    log "SUCCESS" "kubectl proxy (env) unset"
}

module_kubernetes_status() {
    if ! command_exists kubectl; then return 0; fi
    echo "Kubernetes (kubectl):"
    echo "  HTTPS_PROXY: ${HTTPS_PROXY:-Not set}"
}
