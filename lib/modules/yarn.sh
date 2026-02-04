#!/bin/bash
# ============================================================================
# ProxySet Module - Yarn Package Manager
# ============================================================================
# Configures proxy for Yarn (both Yarn Classic 1.x and Yarn Berry 2+).
# ============================================================================

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_yarn_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists yarn; then
        return 0
    fi
    
    log "INFO" "Configuring Yarn proxy..."
    
    # Detect Yarn version
    local yarn_version
    yarn_version=$(yarn --version 2>/dev/null | cut -d. -f1)
    
    if [[ "$yarn_version" -ge 2 ]]; then
        # Yarn Berry (2+) uses different config
        log "DEBUG" "Detected Yarn Berry (v${yarn_version})"
        yarn config set httpProxy "$proxy_url" 2>/dev/null || true
        yarn config set httpsProxy "$proxy_url" 2>/dev/null || true
    else
        # Yarn Classic (1.x)
        log "DEBUG" "Detected Yarn Classic (v${yarn_version})"
        yarn config set proxy "$proxy_url" 2>/dev/null || true
        yarn config set https-proxy "$proxy_url" 2>/dev/null || true
    fi
    
    log "SUCCESS" "Yarn proxy configured."
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_yarn_unset() {
    if ! command_exists yarn; then
        return 0
    fi
    
    log "INFO" "Removing Yarn proxy configuration..."
    
    local yarn_version
    yarn_version=$(yarn --version 2>/dev/null | cut -d. -f1)
    
    if [[ "$yarn_version" -ge 2 ]]; then
        yarn config unset httpProxy 2>/dev/null || true
        yarn config unset httpsProxy 2>/dev/null || true
    else
        yarn config delete proxy 2>/dev/null || true
        yarn config delete https-proxy 2>/dev/null || true
    fi
    
    log "SUCCESS" "Yarn proxy removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_yarn_status() {
    if ! command_exists yarn; then
        return 0
    fi
    
    echo "Yarn Proxy Configuration:"
    
    local yarn_version
    yarn_version=$(yarn --version 2>/dev/null | cut -d. -f1)
    
    if [[ "$yarn_version" -ge 2 ]]; then
        local http_proxy https_proxy
        http_proxy=$(yarn config get httpProxy 2>/dev/null)
        https_proxy=$(yarn config get httpsProxy 2>/dev/null)
        
        if [[ -n "$http_proxy" && "$http_proxy" != "undefined" ]]; then
            echo "  HTTP Proxy: $http_proxy"
        fi
        if [[ -n "$https_proxy" && "$https_proxy" != "undefined" ]]; then
            echo "  HTTPS Proxy: $https_proxy"
        fi
        if [[ -z "$http_proxy" || "$http_proxy" == "undefined" ]] && \
           [[ -z "$https_proxy" || "$https_proxy" == "undefined" ]]; then
            echo "  Not configured"
        fi
    else
        local proxy https_proxy
        proxy=$(yarn config get proxy 2>/dev/null)
        https_proxy=$(yarn config get https-proxy 2>/dev/null)
        
        if [[ -n "$proxy" && "$proxy" != "undefined" ]]; then
            echo "  Proxy: $proxy"
        fi
        if [[ -n "$https_proxy" && "$https_proxy" != "undefined" ]]; then
            echo "  HTTPS Proxy: $https_proxy"
        fi
        if [[ -z "$proxy" || "$proxy" == "undefined" ]] && \
           [[ -z "$https_proxy" || "$https_proxy" == "undefined" ]]; then
            echo "  Not configured"
        fi
    fi
}
