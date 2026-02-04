#!/bin/bash
# ============================================================================
# ProxySet Module - PHP Composer
# ============================================================================
# Configures proxy for PHP Composer package manager.
# Uses composer config commands for persistent configuration.
# ============================================================================

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_composer_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists composer; then
        return 0
    fi
    
    log "INFO" "Configuring Composer proxy..."
    
    # Parse proxy for authentication
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Composer uses http.proxy and https.proxy config
    composer config --global http-proxy "$proxy_url" 2>/dev/null || {
        log "WARN" "Failed to set Composer HTTP proxy"
        return 1
    }
    
    # Also set HTTPS proxy
    composer config --global https-proxy "$proxy_url" 2>/dev/null || true
    
    # Disable TLS if using SOCKS (often needed)
    if [[ "$proto" == "socks"* ]]; then
        composer config --global disable-tls true 2>/dev/null || true
        log "WARN" "Disabled TLS for SOCKS proxy compatibility"
    fi
    
    log "SUCCESS" "Composer proxy configured globally"
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_composer_unset() {
    if ! command_exists composer; then
        return 0
    fi
    
    log "INFO" "Removing Composer proxy configuration..."
    
    # Remove proxy settings
    composer config --global --unset http-proxy 2>/dev/null || true
    composer config --global --unset https-proxy 2>/dev/null || true
    composer config --global --unset disable-tls 2>/dev/null || true
    
    log "SUCCESS" "Composer proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_composer_status() {
    if ! command_exists composer; then
        return 0
    fi
    
    echo "Composer Proxy Configuration:"
    
    local http_proxy https_proxy
    http_proxy=$(composer config --global http-proxy 2>/dev/null)
    https_proxy=$(composer config --global https-proxy 2>/dev/null)
    
    if [[ -n "$http_proxy" && "$http_proxy" != "null" ]]; then
        echo "  HTTP Proxy: $http_proxy"
    fi
    
    if [[ -n "$https_proxy" && "$https_proxy" != "null" ]]; then
        echo "  HTTPS Proxy: $https_proxy"
    fi
    
    if [[ -z "$http_proxy" || "$http_proxy" == "null" ]] && \
       [[ -z "$https_proxy" || "$https_proxy" == "null" ]]; then
        echo "  Not configured"
    fi
    
    # Check if TLS is disabled
    local disable_tls
    disable_tls=$(composer config --global disable-tls 2>/dev/null)
    if [[ "$disable_tls" == "true" ]]; then
        echo "  TLS: Disabled (for SOCKS compatibility)"
    fi
    
    # Show composer version
    local composer_version
    composer_version=$(composer --version 2>/dev/null | head -1 | awk '{print $3}')
    echo "  Composer version: ${composer_version:-unknown}"
}
