#!/bin/bash
# ============================================================================
# ProxySet Module - Ruby Gems
# ============================================================================
# Configures proxy for Ruby's gem package manager.
# Uses both environment variables and .gemrc configuration.
# ============================================================================

# Configuration path
readonly GEMRC="$HOME/.gemrc"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_gem_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists gem; then
        return 0
    fi
    
    log "INFO" "Configuring Ruby Gems proxy..."
    
    # Parse proxy URL
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Backup existing .gemrc
    if [[ -f "$GEMRC" ]] && [[ ! -f "${DATA_DIR}/gemrc.bak" ]]; then
        cp "$GEMRC" "${DATA_DIR}/gemrc.bak"
    fi
    
    # Remove existing proxy settings from .gemrc
    if [[ -f "$GEMRC" ]]; then
        sed -i '/^http_proxy:/d' "$GEMRC"
        sed -i '/^https_proxy:/d' "$GEMRC"
        sed -i '/# ProxySet/d' "$GEMRC"
    fi
    
    # Add proxy to .gemrc
    {
        echo ""
        echo "# ProxySet Configuration"
        echo "http_proxy: $proxy_url"
        echo "https_proxy: $proxy_url"
    } >> "$GEMRC"
    
    # Also set environment variables for current session
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    
    log "SUCCESS" "Ruby Gems proxy configured in $GEMRC"
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_gem_unset() {
    if ! command_exists gem; then
        return 0
    fi
    
    log "INFO" "Removing Ruby Gems proxy configuration..."
    
    if [[ -f "$GEMRC" ]]; then
        sed -i '/^http_proxy:/d' "$GEMRC"
        sed -i '/^https_proxy:/d' "$GEMRC"
        sed -i '/# ProxySet/d' "$GEMRC"
        
        # Clean up empty lines
        sed -i -e :a -e '/^\s*$/d;N;ba' "$GEMRC" 2>/dev/null || true
    fi
    
    log "SUCCESS" "Ruby Gems proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_gem_status() {
    if ! command_exists gem; then
        return 0
    fi
    
    echo "Ruby Gems Proxy Configuration:"
    
    if [[ -f "$GEMRC" ]]; then
        local http_proxy https_proxy
        http_proxy=$(grep "^http_proxy:" "$GEMRC" 2>/dev/null | cut -d: -f2- | tr -d ' ')
        https_proxy=$(grep "^https_proxy:" "$GEMRC" 2>/dev/null | cut -d: -f2- | tr -d ' ')
        
        if [[ -n "$http_proxy" ]]; then
            echo "  HTTP Proxy: $http_proxy"
        fi
        if [[ -n "$https_proxy" ]]; then
            echo "  HTTPS Proxy: $https_proxy"
        fi
        if [[ -z "$http_proxy" && -z "$https_proxy" ]]; then
            echo "  Not configured"
        fi
    else
        echo "  Config file not found ($GEMRC)"
    fi
    
    # Show gem version
    if command_exists gem; then
        local gem_version
        gem_version=$(gem --version 2>/dev/null)
        echo "  gem version: ${gem_version:-unknown}"
    fi
    
    if command_exists ruby; then
        local ruby_version
        ruby_version=$(ruby --version 2>/dev/null | awk '{print $2}')
        echo "  ruby version: ${ruby_version:-unknown}"
    fi
}
