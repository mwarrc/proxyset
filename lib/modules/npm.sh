#!/bin/bash
# ProxySet Module - NPM

module_npm_set() {
    local proxy_url="$1"
    if command_exists npm; then
        log "INFO" "Configuring NPM proxy..."
        npm config set proxy "$proxy_url"
        npm config set https-proxy "$proxy_url"
    fi
}

module_npm_unset() {
    if command_exists npm; then
        log "INFO" "Unsetting NPM proxy..."
        npm config delete proxy
        npm config delete https-proxy
    fi
}

module_npm_status() {
    if command_exists npm; then
        echo "NPM Proxy:"
        echo "  http: $(npm config get proxy | grep -v "null" || echo 'Not set')"
        echo "  https: $(npm config get https-proxy | grep -v "null" || echo 'Not set')"
    fi
}
