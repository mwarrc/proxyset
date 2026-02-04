#!/bin/bash
# ProxySet Module - Tor (Onion Router)
# Configures system to use Tor SOCKS proxy

module_tor_set() {
    local proxy_url="${1:-socks5://127.0.0.1:9050}"
    local no_proxy="$2"
    
    # Check if Tor is running
    if ! pgrep -x "tor" > /dev/null; then
        log "WARN" "Tor process not found. Ensure Tor is running (systemctl start tor)."
    fi
    
    # Tor usually implies 127.0.0.1:9050 socks5
    # If user provided a different URL, we verify, but typically Tor is local.
    
    log "INFO" "Configuring Tor Proxy Chain..."
    
    # We basically set this as the system proxy
    module_env_set "$proxy_url" "$no_proxy"
    
    # Also set specific tools
    if [[ -n "${LOADED_MODULES[curl]:-}" ]]; then module_curl_set "$proxy_url" "$no_proxy"; fi
    if [[ -n "${LOADED_MODULES[wget]:-}" ]]; then module_wget_set "$proxy_url" "$no_proxy"; fi
    if [[ -n "${LOADED_MODULES[brave]:-}" ]]; then module_brave_set "$proxy_url" "$no_proxy"; fi
    if [[ -n "${LOADED_MODULES[firefox]:-}" ]]; then module_firefox_set "$proxy_url" "$no_proxy"; fi
    
    log "SUCCESS" "Tor proxy settings applied."
}

module_tor_unset() {
    log "INFO" "Disabling Tor proxy..."
    module_env_unset
    [[ -n "${LOADED_MODULES[curl]:-}" ]] && module_curl_unset
    [[ -n "${LOADED_MODULES[wget]:-}" ]] && module_wget_unset
    log "SUCCESS" "Tor proxy disabled."
}

module_tor_status() {
    if pgrep -x "tor" > /dev/null; then
        echo "Tor Status: Running"
    else
        echo "Tor Status: Stopped"
    fi
    echo "  Proxy: ${http_proxy:-Not set}"
}
