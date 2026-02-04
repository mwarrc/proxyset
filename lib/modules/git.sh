#!/bin/bash
# ProxySet Module - Git

module_git_set() {
    local proxy_url="$1"
    if command_exists git; then
        log "INFO" "Configuring Git proxy..."
        git config --global http.proxy "$proxy_url"
        git config --global https.proxy "$proxy_url"
    fi
}

module_git_unset() {
    if command_exists git; then
        log "INFO" "Unsetting Git proxy..."
        git config --global --unset http.proxy
        git config --global --unset https.proxy
    fi
}

module_git_status() {
    if command_exists git; then
        echo "Git Proxy:"
        echo "  http: $(git config --global http.proxy || echo 'Not set')"
        echo "  https: $(git config --global https.proxy || echo 'Not set')"
    fi
}
