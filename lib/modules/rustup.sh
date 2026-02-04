#!/bin/bash
# ============================================================================
# ProxySet Module - Rust (rustup & cargo)
# ============================================================================
# Configures proxy for Rust toolchain manager (rustup) and Cargo.
# Uses environment variables and cargo config.
# ============================================================================

# Configuration paths
readonly CARGO_CONFIG="$HOME/.cargo/config.toml"
readonly CARGO_CONFIG_LEGACY="$HOME/.cargo/config"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_rustup_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    # Check if rustup or cargo exists
    if ! command_exists rustup && ! command_exists cargo; then
        return 0
    fi
    
    log "INFO" "Configuring Rust/Cargo proxy..."
    
    # Create cargo directory if needed
    mkdir -p "$HOME/.cargo"
    
    # Use cargo config.toml (modern) or config (legacy)
    local config_file="$CARGO_CONFIG"
    if [[ -f "$CARGO_CONFIG_LEGACY" ]] && [[ ! -f "$CARGO_CONFIG" ]]; then
        config_file="$CARGO_CONFIG_LEGACY"
    fi
    
    # Backup existing config
    if [[ -f "$config_file" ]] && [[ ! -f "${DATA_DIR}/cargo-config.bak" ]]; then
        cp "$config_file" "${DATA_DIR}/cargo-config.bak"
    fi
    
    # Remove existing proxy settings
    if [[ -f "$config_file" ]]; then
        # Remove ProxySet managed sections
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$config_file"
    fi
    
    # Parse proxy for SOCKS detection
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Append proxy configuration for Cargo
    {
        echo ""
        echo "# ProxySet Start"
        echo "[http]"
        echo "proxy = \"${proxy_url}\""
        
        # If SOCKS proxy, add check-revoke = false (often needed with proxies)
        if [[ "$proto" == "socks"* ]]; then
            echo "check-revoke = false"
        fi
        
        echo ""
        echo "[net]"
        echo "# Git fetch with CLI for better proxy support"
        echo "git-fetch-with-cli = true"
        echo "# ProxySet End"
    } >> "$config_file"
    
    log "SUCCESS" "Cargo proxy configured in $config_file"
    
    # Also set environment for rustup downloads
    # These are typically set via env.sh module, but we note them here
    log "INFO" "Note: Set HTTP_PROXY/HTTPS_PROXY environment for rustup component downloads."
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_rustup_unset() {
    if ! command_exists rustup && ! command_exists cargo; then
        return 0
    fi
    
    log "INFO" "Removing Rust/Cargo proxy configuration..."
    
    # Remove from both possible config files
    for config_file in "$CARGO_CONFIG" "$CARGO_CONFIG_LEGACY"; do
        if [[ -f "$config_file" ]]; then
            sed -i '/# ProxySet Start/,/# ProxySet End/d' "$config_file"
            
            # Clean up empty lines
            sed -i -e :a -e '/^\s*$/d;N;ba' "$config_file" 2>/dev/null || true
        fi
    done
    
    log "SUCCESS" "Rust/Cargo proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_rustup_status() {
    if ! command_exists rustup && ! command_exists cargo; then
        return 0
    fi
    
    echo "Rust/Cargo Proxy Configuration:"
    
    # Check cargo config
    local config_file="$CARGO_CONFIG"
    [[ -f "$CARGO_CONFIG_LEGACY" ]] && config_file="$CARGO_CONFIG_LEGACY"
    
    if [[ -f "$config_file" ]]; then
        local proxy
        proxy=$(grep "^proxy" "$config_file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' "')
        
        if [[ -n "$proxy" ]]; then
            echo "  Cargo proxy: $proxy"
        else
            echo "  Cargo proxy: Not configured"
        fi
        
        if grep -q "git-fetch-with-cli" "$config_file" 2>/dev/null; then
            echo "  Git CLI fetch: Enabled"
        fi
    else
        echo "  Cargo config: Not found"
    fi
    
    # Show versions
    if command_exists rustup; then
        local rustup_version
        rustup_version=$(rustup --version 2>/dev/null | head -1 | awk '{print $2}')
        echo "  rustup: ${rustup_version:-unknown}"
    fi
    
    if command_exists cargo; then
        local cargo_version
        cargo_version=$(cargo --version 2>/dev/null | awk '{print $2}')
        echo "  cargo: ${cargo_version:-unknown}"
    fi
}
