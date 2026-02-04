#!/bin/bash
# ProxySet Module - Conda

readonly CONDA_RC="$HOME/.condarc"

module_conda_set() {
    local proxy_url="$1"
    if ! command_exists conda; then return 0; fi
    log "INFO" "Configuring Conda proxy..."
    
    # Conda config interface is reliable
    conda config --set proxy_servers.http "$proxy_url"
    conda config --set proxy_servers.https "$proxy_url"
    log "SUCCESS" "Conda proxy configured in $CONDA_RC"
}

module_conda_unset() {
    if ! command_exists conda; then return 0; fi
    log "INFO" "Removing Conda proxy..."
    conda config --remove-key proxy_servers.http 2>/dev/null || true
    conda config --remove-key proxy_servers.https 2>/dev/null || true
    log "SUCCESS" "Conda proxy removed"
}

module_conda_status() {
    if ! command_exists conda; then return 0; fi
    echo "Conda:"
    conda config --show proxy_servers 2>/dev/null || echo "  Not configured"
}
