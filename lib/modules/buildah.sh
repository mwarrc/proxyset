#!/bin/bash
# ProxySet Module - Buildah

module_buildah_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    if ! command_exists buildah; then return 0; fi
    
    # Buildah respects env vars
    log "INFO" "Configuring Buildah proxy (env)..."
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    log "SUCCESS" "Buildah configured via environment"
}

module_buildah_unset() {
    if ! command_exists buildah; then return 0; fi
    unset HTTP_PROXY HTTPS_PROXY NO_PROXY
    log "SUCCESS" "Buildah proxy unset"
}

module_buildah_status() {
    if ! command_exists buildah; then return 0; fi
    echo "Buildah:"
    echo "  HTTPS_PROXY: ${HTTPS_PROXY:-Not set}"
}
