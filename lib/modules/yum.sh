#!/bin/bash
# ============================================================================
# ProxySet Module - YUM (RHEL/CentOS/Fedora Legacy)
# ============================================================================
# Configures proxy for the YUM package manager used in RHEL, CentOS,
# and older Fedora systems. Also handles subscription-manager for RHEL.
# ============================================================================

# Configuration file path
readonly YUM_CONF="/etc/yum.conf"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_yum_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    # Check if yum exists
    if ! command_exists yum; then
        return 0
    fi
    
    log "INFO" "Configuring YUM proxy..."
    
    if ! check_sudo; then
        log "WARN" "Sudo required to configure YUM. Skipping."
        return 1
    fi
    
    # Parse proxy URL for components
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Backup existing config if not backed up
    if [[ -f "$YUM_CONF" ]] && [[ ! -f "${DATA_DIR}/yum.conf.bak" ]]; then
        sudo cp "$YUM_CONF" "${DATA_DIR}/yum.conf.bak"
    fi
    
    # Remove existing proxy settings
    sudo sed -i '/^proxy=/d' "$YUM_CONF"
    sudo sed -i '/^proxy_username=/d' "$YUM_CONF"
    sudo sed -i '/^proxy_password=/d' "$YUM_CONF"
    
    # Add new proxy settings under [main] section
    # YUM uses http:// format
    local yum_proxy="${proto}://${host}:${port}"
    
    sudo sed -i "/^\[main\]/a proxy=${yum_proxy}" "$YUM_CONF"
    
    # Add authentication if provided
    if [[ -n "$user" ]]; then
        sudo sed -i "/^proxy=/a proxy_username=${user}" "$YUM_CONF"
        if [[ -n "$pass" ]]; then
            sudo sed -i "/^proxy_username=/a proxy_password=${pass}" "$YUM_CONF"
        fi
    fi
    
    log "SUCCESS" "YUM proxy configured: $host:$port"
    
    # Also configure subscription-manager for RHEL
    if command_exists subscription-manager; then
        log "INFO" "Configuring RHEL Subscription Manager proxy..."
        if [[ -n "$user" && -n "$pass" ]]; then
            sudo subscription-manager config \
                --server.proxy_hostname="$host" \
                --server.proxy_port="$port" \
                --server.proxy_user="$user" \
                --server.proxy_password="$pass" 2>/dev/null || true
        else
            sudo subscription-manager config \
                --server.proxy_hostname="$host" \
                --server.proxy_port="$port" 2>/dev/null || true
        fi
    fi
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_yum_unset() {
    if ! command_exists yum; then
        return 0
    fi
    
    log "INFO" "Removing YUM proxy configuration..."
    
    if ! check_sudo; then
        log "WARN" "Sudo required to modify YUM config. Skipping."
        return 1
    fi
    
    # Remove proxy settings
    sudo sed -i '/^proxy=/d' "$YUM_CONF"
    sudo sed -i '/^proxy_username=/d' "$YUM_CONF"
    sudo sed -i '/^proxy_password=/d' "$YUM_CONF"
    
    # Clear subscription-manager proxy
    if command_exists subscription-manager; then
        sudo subscription-manager config \
            --server.proxy_hostname="" \
            --server.proxy_port="" \
            --server.proxy_user="" \
            --server.proxy_password="" 2>/dev/null || true
    fi
    
    log "SUCCESS" "YUM proxy removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_yum_status() {
    if ! command_exists yum; then
        return 0
    fi
    
    echo "YUM Proxy Configuration:"
    
    if [[ -f "$YUM_CONF" ]]; then
        local proxy
        proxy=$(grep "^proxy=" "$YUM_CONF" 2>/dev/null | cut -d= -f2-)
        
        if [[ -n "$proxy" ]]; then
            echo "  Proxy: $proxy"
            
            local user
            user=$(grep "^proxy_username=" "$YUM_CONF" 2>/dev/null | cut -d= -f2-)
            [[ -n "$user" ]] && echo "  Username: $user"
            
            # Don't show password, just indicate if set
            if grep -q "^proxy_password=" "$YUM_CONF" 2>/dev/null; then
                echo "  Password: [configured]"
            fi
        else
            echo "  Not configured"
        fi
    else
        echo "  Config file not found: $YUM_CONF"
    fi
    
    # Show subscription-manager status if available
    if command_exists subscription-manager; then
        echo ""
        echo "RHEL Subscription Manager Proxy:"
        local sm_host
        sm_host=$(sudo subscription-manager config --list 2>/dev/null | grep "proxy_hostname" | awk '{print $3}')
        if [[ -n "$sm_host" && "$sm_host" != "[]" ]]; then
            echo "  Host: $sm_host"
        else
            echo "  Not configured"
        fi
    fi
}
