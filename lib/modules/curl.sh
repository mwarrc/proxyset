#!/bin/bash
# ============================================================================
# ProxySet Module - curl Global Configuration
# ============================================================================
# Configures user-level proxy settings for curl via ~/.curlrc.
# ============================================================================

# Configuration path
readonly USER_CURLRC="$HOME/.curlrc"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_curl_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists curl; then
        return 0
    fi
    
    log "INFO" "Configuring curl proxy..."
    
    # Parse proxy URL for SOCKS detection
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Backup existing config
    if [[ -f "$USER_CURLRC" ]] && [[ ! -f "${DATA_DIR}/curlrc.bak" ]]; then
        cp "$USER_CURLRC" "${DATA_DIR}/curlrc.bak"
    fi
    
    # Remove existing proxy settings
    if [[ -f "$USER_CURLRC" ]]; then
        sed -i '/^proxy/d' "$USER_CURLRC"
        sed -i '/^noproxy/d' "$USER_CURLRC"
        sed -i '/^proxy-user/d' "$USER_CURLRC"
        sed -i '/# ProxySet/d' "$USER_CURLRC"
    fi
    
    # Write new proxy config
    {
        echo ""
        echo "# ProxySet Configuration"
        
        # Use appropriate option based on proxy type
        case "$proto" in
            socks5|socks5h)
                echo "proxy = \"socks5h://${host}:${port}\""
                ;;
            socks4)
                echo "proxy = \"socks4://${host}:${port}\""
                ;;
            *)
                echo "proxy = \"${proxy_url}\""
                ;;
        esac
        
        # Add no_proxy
        echo "noproxy = \"${no_proxy}\""
        
        # Add authentication if provided
        if [[ -n "$user" ]]; then
            if [[ -n "$pass" ]]; then
                echo "proxy-user = \"${user}:${pass}\""
            else
                echo "proxy-user = \"${user}\""
            fi
        fi
    } >> "$USER_CURLRC"
    
    # Set secure permissions
    chmod 600 "$USER_CURLRC"
    
    log "SUCCESS" "curl proxy configured in $USER_CURLRC"
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_curl_unset() {
    if ! command_exists curl; then
        return 0
    fi
    
    log "INFO" "Removing curl proxy configuration..."
    
    if [[ -f "$USER_CURLRC" ]]; then
        sed -i '/^proxy/d' "$USER_CURLRC"
        sed -i '/^noproxy/d' "$USER_CURLRC"
        sed -i '/^proxy-user/d' "$USER_CURLRC"
        sed -i '/# ProxySet/d' "$USER_CURLRC"
        
        # Clean up empty lines
        sed -i -e :a -e '/^\s*$/d;N;ba' "$USER_CURLRC" 2>/dev/null || true
    fi
    
    log "SUCCESS" "curl proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_curl_status() {
    if ! command_exists curl; then
        return 0
    fi
    
    echo "curl Proxy Configuration:"
    
    if [[ -f "$USER_CURLRC" ]]; then
        local proxy
        proxy=$(grep "^proxy" "$USER_CURLRC" 2>/dev/null | grep -v "proxy-user" | head -1 | cut -d= -f2- | tr -d ' "')
        
        if [[ -n "$proxy" ]]; then
            echo "  Proxy: $proxy"
            
            local noproxy
            noproxy=$(grep "^noproxy" "$USER_CURLRC" 2>/dev/null | cut -d= -f2- | tr -d ' "')
            [[ -n "$noproxy" ]] && echo "  No Proxy: $noproxy"
            
            if grep -q "^proxy-user" "$USER_CURLRC" 2>/dev/null; then
                echo "  Authentication: Configured"
            fi
        else
            echo "  Not configured"
        fi
    else
        echo "  Config file not found ($USER_CURLRC)"
    fi
    
    # Show curl version
    local curl_version
    curl_version=$(curl --version 2>/dev/null | head -1 | awk '{print $2}')
    echo "  curl version: ${curl_version:-unknown}"
}
