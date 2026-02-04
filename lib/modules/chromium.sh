#!/bin/bash
# ============================================================================
# ProxySet Module - Chromium Browser
# ============================================================================
# Configures system-wide proxy policy for Chromium-based browsers.
# Uses managed policies directory for enterprise-style configuration.
# ============================================================================

# Policy directories
readonly CHROMIUM_POLICY_DIR="/etc/chromium/policies/managed"
readonly CHROME_POLICY_DIR="/etc/opt/chrome/policies/managed"
readonly CHROMIUM_POLICY_FILE="proxyset_proxy.json"

# ----------------------------------------------------------------------------
# Set Proxy
# ----------------------------------------------------------------------------

module_chromium_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    # Check if chromium or chrome exists
    if ! command_exists chromium && ! command_exists chromium-browser && \
       ! command_exists google-chrome && ! command_exists chrome; then
        return 0
    fi
    
    log "INFO" "Configuring Chromium/Chrome system proxy policy..."
    
    if ! check_sudo; then
        log "WARN" "Sudo required to configure Chromium system policy. Skipping."
        return 1
    fi
    
    # Parse proxy URL
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Determine proxy mode and server format
    local proxy_mode="fixed_servers"
    local proxy_server
    
    if [[ "$proto" == "socks"* ]]; then
        proxy_server="socks5://${host}:${port}"
    else
        proxy_server="${host}:${port}"
    fi
    
    # Create policy JSON
    local policy_content
    policy_content=$(cat <<EOF
{
  "ProxyMode": "$proxy_mode",
  "ProxyServer": "$proxy_server",
  "ProxyBypassList": "$no_proxy"
}
EOF
)
    
    # Install policy for Chromium
    if command_exists chromium || command_exists chromium-browser; then
        sudo mkdir -p "$CHROMIUM_POLICY_DIR"
        echo "$policy_content" | sudo tee "$CHROMIUM_POLICY_DIR/$CHROMIUM_POLICY_FILE" > /dev/null
        log "SUCCESS" "Chromium policy installed: $CHROMIUM_POLICY_DIR/$CHROMIUM_POLICY_FILE"
    fi
    
    # Install policy for Chrome
    if command_exists google-chrome || command_exists chrome; then
        sudo mkdir -p "$CHROME_POLICY_DIR"
        echo "$policy_content" | sudo tee "$CHROME_POLICY_DIR/$CHROMIUM_POLICY_FILE" > /dev/null
        log "SUCCESS" "Chrome policy installed: $CHROME_POLICY_DIR/$CHROMIUM_POLICY_FILE"
    fi
    
    log "INFO" "Restart browser for changes to take effect"
}

# ----------------------------------------------------------------------------
# Unset Proxy
# ----------------------------------------------------------------------------

module_chromium_unset() {
    if ! command_exists chromium && ! command_exists chromium-browser && \
       ! command_exists google-chrome && ! command_exists chrome; then
        return 0
    fi
    
    log "INFO" "Removing Chromium/Chrome proxy policy..."
    
    if ! check_sudo; then
        log "WARN" "Sudo required to remove Chromium policy. Skipping."
        return 1
    fi
    
    # Remove Chromium policy
    if [[ -f "$CHROMIUM_POLICY_DIR/$CHROMIUM_POLICY_FILE" ]]; then
        sudo rm -f "$CHROMIUM_POLICY_DIR/$CHROMIUM_POLICY_FILE"
        log "SUCCESS" "Chromium policy removed"
    fi
    
    # Remove Chrome policy
    if [[ -f "$CHROME_POLICY_DIR/$CHROMIUM_POLICY_FILE" ]]; then
        sudo rm -f "$CHROME_POLICY_DIR/$CHROMIUM_POLICY_FILE"
        log "SUCCESS" "Chrome policy removed"
    fi
}

# ----------------------------------------------------------------------------
# Status Check
# ----------------------------------------------------------------------------

module_chromium_status() {
    if ! command_exists chromium && ! command_exists chromium-browser && \
       ! command_exists google-chrome && ! command_exists chrome; then
        return 0
    fi
    
    echo "Chromium/Chrome Proxy Policy:"
    
    # Check Chromium policy
    if [[ -f "$CHROMIUM_POLICY_DIR/$CHROMIUM_POLICY_FILE" ]]; then
        echo "  Chromium policy: Configured"
        if command_exists jq; then
            local proxy_server
            proxy_server=$(jq -r '.ProxyServer // "unknown"' "$CHROMIUM_POLICY_DIR/$CHROMIUM_POLICY_FILE" 2>/dev/null)
            echo "    Server: $proxy_server"
        fi
    else
        echo "  Chromium policy: Not configured"
    fi
    
    # Check Chrome policy
    if [[ -f "$CHROME_POLICY_DIR/$CHROMIUM_POLICY_FILE" ]]; then
        echo "  Chrome policy: Configured"
        if command_exists jq; then
            local proxy_server
            proxy_server=$(jq -r '.ProxyServer // "unknown"' "$CHROME_POLICY_DIR/$CHROMIUM_POLICY_FILE" 2>/dev/null)
            echo "    Server: $proxy_server"
        fi
    else
        echo "  Chrome policy: Not configured"
    fi
    
    # Show browser versions
    if command_exists chromium || command_exists chromium-browser; then
        local chromium_version
        chromium_version=$(chromium --version 2>/dev/null || chromium-browser --version 2>/dev/null | awk '{print $2}')
        echo "  Chromium version: ${chromium_version:-unknown}"
    fi
    
    if command_exists google-chrome || command_exists chrome; then
        local chrome_version
        chrome_version=$(google-chrome --version 2>/dev/null || chrome --version 2>/dev/null | awk '{print $3}')
        echo "  Chrome version: ${chrome_version:-unknown}"
    fi
}
