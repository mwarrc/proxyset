#!/bin/bash
# ProxySet Module - Containerd
# Note: Usually requires restarting the service which we avoid forcing automatically, but we configure the environment.

readonly CONTAINERD_ENV_DIR="/etc/systemd/system/containerd.service.d"
readonly CONTAINERD_PROXY_CONF="$CONTAINERD_ENV_DIR/http-proxy.conf"

module_containerd_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    if ! command_exists containerd; then return 0; fi
    
    log "INFO" "Configuring Containerd proxy..."
    if ! check_sudo; then log "WARN" "Sudo required for containerd. Skipping."; return 1; fi
    
    sudo mkdir -p "$CONTAINERD_ENV_DIR"
    {
        echo "[Service]"
        echo "Environment=\"HTTP_PROXY=$proxy_url\""
        echo "Environment=\"HTTPS_PROXY=$proxy_url\""
        echo "Environment=\"NO_PROXY=$no_proxy\""
    } | sudo tee "$CONTAINERD_PROXY_CONF" > /dev/null
    
    sudo systemctl daemon-reload
    log "SUCCESS" "Containerd proxy configured (restart required)"
}

module_containerd_unset() {
    if ! command_exists containerd; then return 0; fi
    if ! check_sudo; then return 1; fi
    if [[ -f "$CONTAINERD_PROXY_CONF" ]]; then
        sudo rm -f "$CONTAINERD_PROXY_CONF"
        sudo systemctl daemon-reload
        log "SUCCESS" "Containerd proxy removed"
    fi
}

module_containerd_status() {
    if ! command_exists containerd; then return 0; fi
    echo "Containerd:"
    [[ -f "$CONTAINERD_PROXY_CONF" ]] && echo "  Configured in: $CONTAINERD_PROXY_CONF" || echo "  Not configured"
}
