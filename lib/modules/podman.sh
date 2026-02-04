#!/bin/bash
# ============================================================================
# ProxySet Module - Podman Containers
# ============================================================================
# Configures proxy for Podman container runtime (rootless and rootful).
# Similar to Docker but uses different config locations.
# ============================================================================

# Configuration paths
readonly PODMAN_USER_CONF="$HOME/.config/containers/containers.conf"
readonly PODMAN_SYSTEM_CONF="/etc/containers/containers.conf"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_podman_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists podman; then
        return 0
    fi
    
    log "INFO" "Configuring Podman proxy..."
    
    # Create user config directory
    mkdir -p "$(dirname "$PODMAN_USER_CONF")"
    
    # Parse proxy for host/port
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Backup existing config
    if [[ -f "$PODMAN_USER_CONF" ]] && [[ ! -f "${DATA_DIR}/containers.conf.bak" ]]; then
        cp "$PODMAN_USER_CONF" "${DATA_DIR}/containers.conf.bak"
    fi
    
    # Create or update containers.conf with proxy settings
    # Using [engine] section for environment variables
    
    if [[ -f "$PODMAN_USER_CONF" ]]; then
        # Remove existing proxy env from config
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$PODMAN_USER_CONF"
    fi
    
    # Append proxy configuration
    {
        echo ""
        echo "# ProxySet Start"
        echo "[engine]"
        echo "env = ["
        echo "    \"HTTP_PROXY=${proxy_url}\","
        echo "    \"HTTPS_PROXY=${proxy_url}\","
        echo "    \"http_proxy=${proxy_url}\","
        echo "    \"https_proxy=${proxy_url}\","
        echo "    \"NO_PROXY=${no_proxy}\","
        echo "    \"no_proxy=${no_proxy}\""
        echo "]"
        echo "# ProxySet End"
    } >> "$PODMAN_USER_CONF"
    
    log "SUCCESS" "Podman user proxy configured."
    
    # Also set up systemd user service environment for rootless podman
    local systemd_env_dir="$HOME/.config/systemd/user/podman.service.d"
    mkdir -p "$systemd_env_dir"
    
    cat > "$systemd_env_dir/http-proxy.conf" <<EOF
[Service]
Environment="HTTP_PROXY=${proxy_url}"
Environment="HTTPS_PROXY=${proxy_url}"
Environment="NO_PROXY=${no_proxy}"
EOF
    
    # Reload systemd user daemon if available
    if command_exists systemctl; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi
    
    log "SUCCESS" "Podman systemd user service proxy configured."
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_podman_unset() {
    if ! command_exists podman; then
        return 0
    fi
    
    log "INFO" "Removing Podman proxy configuration..."
    
    # Remove from containers.conf
    if [[ -f "$PODMAN_USER_CONF" ]]; then
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$PODMAN_USER_CONF"
    fi
    
    # Remove systemd user service override
    local systemd_env_dir="$HOME/.config/systemd/user/podman.service.d"
    [[ -f "$systemd_env_dir/http-proxy.conf" ]] && rm -f "$systemd_env_dir/http-proxy.conf"
    
    if command_exists systemctl; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi
    
    log "SUCCESS" "Podman proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_podman_status() {
    if ! command_exists podman; then
        return 0
    fi
    
    echo "Podman Proxy Configuration:"
    
    # Check user config
    if [[ -f "$PODMAN_USER_CONF" ]]; then
        if grep -q "ProxySet" "$PODMAN_USER_CONF"; then
            echo "  User config: Configured"
            local proxy
            proxy=$(grep "HTTP_PROXY" "$PODMAN_USER_CONF" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '",')
            [[ -n "$proxy" ]] && echo "  HTTP_PROXY: $proxy"
        else
            echo "  User config: Not configured"
        fi
    else
        echo "  User config: Not found"
    fi
    
    # Check systemd user service
    local systemd_env="$HOME/.config/systemd/user/podman.service.d/http-proxy.conf"
    if [[ -f "$systemd_env" ]]; then
        echo "  Systemd user service: Configured"
    else
        echo "  Systemd user service: Not configured"
    fi
    
    # Show podman version
    local podman_version
    podman_version=$(podman --version 2>/dev/null | awk '{print $3}')
    echo "  Podman version: ${podman_version:-unknown}"
}
