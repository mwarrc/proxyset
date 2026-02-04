#!/bin/bash
# ============================================================================
# ProxySet Module - Go (GOPROXY)
# ============================================================================
# Configures proxy environment for Go modules and the Go toolchain.
# Handles GOPROXY, GONOPROXY, GOPRIVATE, and HTTP_PROXY for go commands.
# ============================================================================

# Config file for persistent Go proxy settings
readonly GO_PROXY_CONFIG="${CONFIG_DIR:-$HOME/.config/proxyset}/go-env"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_go_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists go; then
        return 0
    fi
    
    log "INFO" "Configuring Go proxy environment..."
    
    # Create config directory
    mkdir -p "$(dirname "$GO_PROXY_CONFIG")"
    
    # For Go, we primarily need HTTP_PROXY for module downloads
    # GOPROXY is for the Go module proxy (proxy.golang.org by default)
    
    # Write persistent config
    cat > "$GO_PROXY_CONFIG" <<EOF
# ProxySet Go Environment Configuration
# Source this file in your shell profile for persistent Go proxy settings

export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"
export GONOPROXY="${no_proxy}"
export GONOSUMDB="${no_proxy}"
export GOPRIVATE="${no_proxy}"

# HTTP proxy for module downloads
export http_proxy="${proxy_url}"
export https_proxy="${proxy_url}"
export HTTP_PROXY="${proxy_url}"
export HTTPS_PROXY="${proxy_url}"
EOF
    
    # Set for current session
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export GONOPROXY="$no_proxy"
    export GONOSUMDB="$no_proxy"
    export GOPRIVATE="$no_proxy"
    
    # Add source line to .bashrc if not present
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "go-env" "$HOME/.bashrc"; then
            echo "" >> "$HOME/.bashrc"
            echo "# ProxySet Go Environment" >> "$HOME/.bashrc"
            echo "[[ -f \"$GO_PROXY_CONFIG\" ]] && source \"$GO_PROXY_CONFIG\"" >> "$HOME/.bashrc"
        fi
    fi
    
    log "SUCCESS" "Go proxy configured."
    log "INFO" "Run 'source $GO_PROXY_CONFIG' or restart shell to apply."
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_go_unset() {
    if ! command_exists go; then
        return 0
    fi
    
    log "INFO" "Removing Go proxy configuration..."
    
    # Remove config file
    [[ -f "$GO_PROXY_CONFIG" ]] && rm -f "$GO_PROXY_CONFIG"
    
    # Remove from .bashrc
    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i '/# ProxySet Go Environment/d' "$HOME/.bashrc"
        sed -i '/go-env/d' "$HOME/.bashrc"
    fi
    
    # Unset from current session
    unset GONOPROXY GONOSUMDB GOPRIVATE
    
    log "SUCCESS" "Go proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_go_status() {
    if ! command_exists go; then
        return 0
    fi
    
    echo "Go Proxy Configuration:"
    
    # Show current environment
    local goproxy="${GOPROXY:-not set}"
    local gonoproxy="${GONOPROXY:-not set}"
    local goprivate="${GOPRIVATE:-not set}"
    
    echo "  GOPROXY: $goproxy"
    echo "  GONOPROXY: $gonoproxy"
    echo "  GOPRIVATE: $goprivate"
    
    # Check for persistent config
    if [[ -f "$GO_PROXY_CONFIG" ]]; then
        echo "  Config file: $GO_PROXY_CONFIG (exists)"
    else
        echo "  Config file: not configured"
    fi
    
    # Show Go version for context
    local go_version
    go_version=$(go version 2>/dev/null | awk '{print $3}')
    echo "  Go version: ${go_version:-unknown}"
}
