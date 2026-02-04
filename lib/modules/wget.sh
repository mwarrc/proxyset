#!/bin/bash
# ============================================================================
# ProxySet Module - wget Global Configuration
# ============================================================================
# Configures system-wide and user-level proxy settings for wget.
# Uses ~/.wgetrc for user config and /etc/wgetrc for system config.
# ============================================================================

# Configuration paths
readonly USER_WGETRC="$HOME/.wgetrc"
readonly SYSTEM_WGETRC="/etc/wgetrc"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_wget_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists wget; then
        return 0
    fi
    
    log "INFO" "Configuring wget proxy..."
    
    # Parse proxy URL
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Build wget proxy format
    local wget_proxy="${proto}://${host}:${port}"
    
    # Backup existing user config
    if [[ -f "$USER_WGETRC" ]] && [[ ! -f "${DATA_DIR}/wgetrc.bak" ]]; then
        cp "$USER_WGETRC" "${DATA_DIR}/wgetrc.bak"
    fi
    
    # Remove existing proxy settings from user config
    if [[ -f "$USER_WGETRC" ]]; then
        sed -i '/^http_proxy/d' "$USER_WGETRC"
        sed -i '/^https_proxy/d' "$USER_WGETRC"
        sed -i '/^ftp_proxy/d' "$USER_WGETRC"
        sed -i '/^no_proxy/d' "$USER_WGETRC"
        sed -i '/^use_proxy/d' "$USER_WGETRC"
        sed -i '/^proxy_user/d' "$USER_WGETRC"
        sed -i '/^proxy_password/d' "$USER_WGETRC"
        sed -i '/# ProxySet/d' "$USER_WGETRC"
    fi
    
    # Write new proxy config
    {
        echo ""
        echo "# ProxySet Configuration"
        echo "use_proxy = on"
        echo "http_proxy = $wget_proxy"
        echo "https_proxy = $wget_proxy"
        echo "ftp_proxy = $wget_proxy"
        echo "no_proxy = $no_proxy"
        
        # Add authentication if provided
        if [[ -n "$user" ]]; then
            echo "proxy_user = $user"
            if [[ -n "$pass" ]]; then
                echo "proxy_password = $pass"
            fi
        fi
    } >> "$USER_WGETRC"
    
    # Set secure permissions (contains password)
    chmod 600 "$USER_WGETRC"
    
    log "SUCCESS" "wget proxy configured in $USER_WGETRC"
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_wget_unset() {
    if ! command_exists wget; then
        return 0
    fi
    
    log "INFO" "Removing wget proxy configuration..."
    
    if [[ -f "$USER_WGETRC" ]]; then
        # Remove all proxy-related settings
        sed -i '/^http_proxy/d' "$USER_WGETRC"
        sed -i '/^https_proxy/d' "$USER_WGETRC"
        sed -i '/^ftp_proxy/d' "$USER_WGETRC"
        sed -i '/^no_proxy/d' "$USER_WGETRC"
        sed -i '/^use_proxy/d' "$USER_WGETRC"
        sed -i '/^proxy_user/d' "$USER_WGETRC"
        sed -i '/^proxy_password/d' "$USER_WGETRC"
        sed -i '/# ProxySet/d' "$USER_WGETRC"
        
        # Remove empty lines at end of file
        sed -i -e :a -e '/^\s*$/d;N;ba' "$USER_WGETRC" 2>/dev/null || true
    fi
    
    log "SUCCESS" "wget proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_wget_status() {
    if ! command_exists wget; then
        return 0
    fi
    
    echo "wget Proxy Configuration:"
    
    # Check user config
    if [[ -f "$USER_WGETRC" ]]; then
        local use_proxy http_proxy
        use_proxy=$(grep "^use_proxy" "$USER_WGETRC" 2>/dev/null | cut -d= -f2 | tr -d ' ')
        http_proxy=$(grep "^http_proxy" "$USER_WGETRC" 2>/dev/null | cut -d= -f2- | tr -d ' ')
        
        if [[ "$use_proxy" == "on" && -n "$http_proxy" ]]; then
            echo "  Status: Enabled"
            echo "  HTTP Proxy: $http_proxy"
            
            local https_proxy
            https_proxy=$(grep "^https_proxy" "$USER_WGETRC" 2>/dev/null | cut -d= -f2- | tr -d ' ')
            [[ -n "$https_proxy" ]] && echo "  HTTPS Proxy: $https_proxy"
            
            local no_proxy
            no_proxy=$(grep "^no_proxy" "$USER_WGETRC" 2>/dev/null | cut -d= -f2- | tr -d ' ')
            [[ -n "$no_proxy" ]] && echo "  No Proxy: $no_proxy"
            
            # Check if auth is configured
            if grep -q "^proxy_user" "$USER_WGETRC" 2>/dev/null; then
                echo "  Authentication: Configured"
            fi
        else
            echo "  Not configured"
        fi
    else
        echo "  Config file not found"
    fi
    
    # Check system config
    if [[ -f "$SYSTEM_WGETRC" ]] && check_sudo; then
        local sys_proxy
        sys_proxy=$(grep "^http_proxy" "$SYSTEM_WGETRC" 2>/dev/null | cut -d= -f2- | tr -d ' ')
        if [[ -n "$sys_proxy" ]]; then
            echo "  System proxy: $sys_proxy"
        fi
    fi
}
