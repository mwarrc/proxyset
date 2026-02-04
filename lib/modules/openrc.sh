#!/bin/bash
# ProxySet Module - OpenRC
# Global settings in /etc/conf.d/net or similar

module_openrc_set() {
    if ! command_exists rc-update; then return 0; fi
    log "INFO" "OpenRC: Ensure 'env' module sets /etc/profile for global coverage."
}

module_openrc_unset() {
    true
}

module_openrc_status() {
    if ! command_exists rc-update; then return 0; fi
    echo "OpenRC: Managed via System Env"
}
