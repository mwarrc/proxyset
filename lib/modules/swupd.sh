#!/bin/bash
# ProxySet Module - Clear Linux (swupd)

module_swupd_set() {
    local proxy_url="$1"
    if ! command_exists swupd; then return 0; fi
    log "INFO" "Configuring swupd (env)..."
    # swupd uses standard env
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    log "SUCCESS" "swupd: Env vars exported"
}

module_swupd_unset() {
    if ! command_exists swupd; then return 0; fi
    unset http_proxy https_proxy
}

module_swupd_status() {
    if ! command_exists swupd; then return 0; fi
    echo "swupd: ${https_proxy:-Not set}"
}
