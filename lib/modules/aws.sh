#!/bin/bash
# ============================================================================
# ProxySet Module - AWS CLI
# ============================================================================
# Configures proxy for AWS Command Line Interface.
# Uses AWS CLI config file and environment variables.
# ============================================================================

# Configuration paths
readonly AWS_CONFIG="$HOME/.aws/config"
readonly AWS_CREDENTIALS="$HOME/.aws/credentials"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_aws_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists aws; then
        return 0
    fi
    
    log "INFO" "Configuring AWS CLI proxy..."
    
    # Create AWS config directory
    mkdir -p "$HOME/.aws"
    
    # Backup existing config
    if [[ -f "$AWS_CONFIG" ]] && [[ ! -f "${DATA_DIR}/aws_config.bak" ]]; then
        cp "$AWS_CONFIG" "${DATA_DIR}/aws_config.bak"
    fi
    
    # Parse proxy URL
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Remove existing ProxySet configuration
    if [[ -f "$AWS_CONFIG" ]]; then
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$AWS_CONFIG"
    fi
    
    # Add proxy configuration to AWS config
    # AWS CLI uses HTTP_PROXY/HTTPS_PROXY env vars, but we document it in config
    {
        echo ""
        echo "# ProxySet Start"
        echo "# AWS CLI uses HTTP_PROXY and HTTPS_PROXY environment variables"
        echo "# These are set by the 'env' module"
        echo "# Proxy: $proxy_url"
        echo "# No Proxy: $no_proxy"
        echo "# ProxySet End"
    } >> "$AWS_CONFIG"
    
    # Set environment variables for current session
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    export no_proxy="$no_proxy"
    
    # AWS CLI also respects these
    export AWS_CA_BUNDLE="${AWS_CA_BUNDLE:-}"
    
    log "SUCCESS" "AWS CLI proxy configured"
    log "INFO" "Note: Ensure 'env' module is also configured for persistent proxy"
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_aws_unset() {
    if ! command_exists aws; then
        return 0
    fi
    
    log "INFO" "Removing AWS CLI proxy configuration..."
    
    if [[ -f "$AWS_CONFIG" ]]; then
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$AWS_CONFIG"
        
        # Clean up empty lines
        sed -i -e :a -e '/^\s*$/d;N;ba' "$AWS_CONFIG" 2>/dev/null || true
    fi
    
    log "SUCCESS" "AWS CLI proxy configuration removed."
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_aws_status() {
    if ! command_exists aws; then
        return 0
    fi
    
    echo "AWS CLI Proxy Configuration:"
    
    # Check environment variables
    if [[ -n "${HTTP_PROXY:-}" ]]; then
        echo "  HTTP_PROXY: ${HTTP_PROXY}"
    fi
    
    if [[ -n "${HTTPS_PROXY:-}" ]]; then
        echo "  HTTPS_PROXY: ${HTTPS_PROXY}"
    fi
    
    if [[ -n "${NO_PROXY:-}" ]]; then
        echo "  NO_PROXY: ${NO_PROXY}"
    fi
    
    if [[ -z "${HTTP_PROXY:-}" && -z "${HTTPS_PROXY:-}" ]]; then
        echo "  Environment: Not configured"
    fi
    
    # Check config file
    if [[ -f "$AWS_CONFIG" ]] && grep -q "ProxySet" "$AWS_CONFIG" 2>/dev/null; then
        echo "  Config file: Documented in $AWS_CONFIG"
    fi
    
    # Show AWS CLI version
    local aws_version
    aws_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
    echo "  AWS CLI version: ${aws_version:-unknown}"
    
    # Show current AWS profile
    local aws_profile="${AWS_PROFILE:-default}"
    echo "  Active profile: $aws_profile"
}
