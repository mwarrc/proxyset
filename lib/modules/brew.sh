#!/bin/bash
# ============================================================================
# ProxySet Module - Homebrew / Linuxbrew
# ============================================================================
# Configures proxy for Homebrew package manager.
# Homebrew relies heavily on standard environment variables and curl.
# ============================================================================

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_brew_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists brew; then
        return 0
    fi
    
    log "INFO" "Configuring Homebrew proxy..."
    
    # Homebrew uses standard environment variables
    # We set them here for the current session and rely on env.sh for persistence
    export ALL_PROXY="$proxy_url"
    export FTP_PROXY="$proxy_url"
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    export no_proxy="$no_proxy"
    
    # Homebrew also uses curl, so ensure curl module is managed if available
    if [[ -n "${LOADED_MODULES[curl]:-}" ]]; then
        module_curl_set "$proxy_url" "$no_proxy"
    fi
    
    # Git is used for taps/updates
    if [[ -n "${LOADED_MODULES[git]:-}" ]]; then
        module_git_set "$proxy_url" "$no_proxy"
    fi
    
    log "SUCCESS" "Homebrew proxy environment variables export."
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_brew_unset() {
    if ! command_exists brew; then
        return 0
    fi
    
    log "INFO" "Unsetting Homebrew proxy environment..."
    
    unset ALL_PROXY FTP_PROXY HTTP_PROXY HTTPS_PROXY NO_PROXY
    unset http_proxy https_proxy no_proxy
    
    log "SUCCESS" "Homebrew proxy removed (env vars unset)."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_brew_status() {
    if ! command_exists brew; then
        return 0
    fi
    
    echo "Homebrew Proxy Configuration:"
    echo "  ALL_PROXY: ${ALL_PROXY:-Not set}"
    echo "  HTTP_PROXY: ${HTTP_PROXY:-Not set}"
    
    local brew_version
    brew_version=$(brew --version | head -n 1 | awk '{print $2}')
    echo "  Brew version: ${brew_version:-unknown}"
}
