#!/bin/bash
# ============================================================================
# ProxySet Systemd Module
# ============================================================================
# Configures system-wide proxy settings via systemd DefaultEnvironment.
# ============================================================================

readonly SYSTEMD_CONF_DIR="/etc/systemd/system.conf.d"
readonly SYSTEMD_PROXY_CONF="$SYSTEMD_CONF_DIR/proxy.conf"

module_systemd_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists systemctl; then return 0; fi
    
    log "INFO" "Configuring systemd global proxy..."
    
    if ! check_sudo; then
        log "WARN" "Sudo required for systemd configuration. Skipping."
        return 1
    fi
    
    sudo mkdir -p "$SYSTEMD_CONF_DIR"
    
    {
        echo "[Manager]"
        echo "DefaultEnvironment=\"HTTP_PROXY=$proxy_url\" \"HTTPS_PROXY=$proxy_url\" \"NO_PROXY=$no_proxy\" \"http_proxy=$proxy_url\" \"https_proxy=$proxy_url\" \"no_proxy=$no_proxy\""
    } | sudo tee "$SYSTEMD_PROXY_CONF" > /dev/null
    
    # Reload systemd manager configuration
    sudo systemctl daemon-reexec
    
    log "SUCCESS" "Systemd global proxy configured."
}

module_systemd_unset() {
    if ! command_exists systemctl; then return 0; fi
    
    log "INFO" "Removing systemd global proxy..."
    
    if ! check_sudo; then
        log "WARN" "Sudo required. Skipping."
        return 1
    fi
    
    if [[ -f "$SYSTEMD_PROXY_CONF" ]]; then
        sudo rm -f "$SYSTEMD_PROXY_CONF"
        sudo systemctl daemon-reexec
        log "SUCCESS" "Systemd global proxy removed."
    fi
}

module_systemd_status() {
    if ! command_exists systemctl; then return 0; fi
    
    echo "Systemd Global Proxy:"
    if [[ -f "$SYSTEMD_PROXY_CONF" ]]; then
        echo "  Configured in: $SYSTEMD_PROXY_CONF"
        if check_sudo; then
            sudo grep "DefaultEnvironment" "$SYSTEMD_PROXY_CONF" | sed 's/DefaultEnvironment=//'
        else
            echo "  (Requires sudo to view content)"
        fi
    else
        echo "  Not configured"
    fi
}
