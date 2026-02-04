#!/bin/bash
# ProxySet Core - Health Check Module

check_connectivity() {
    local url="${1:-http://www.google.com}"
    log "INFO" "Testing connectivity to $url..."
    
    if command_exists curl; then
        if curl -s --head --connect-timeout 5 "$url" > /dev/null; then
            log "SUCCESS" "Connection successful!"
            return 0
        else
            log "ERROR" "Connection failed. Check your proxy settings or internet connection."
            return 1
        fi
    else
        log "WARN" "curl not found. Using ping as fallback..."
        if ping -c 1 -W 5 google.com > /dev/null; then
            log "SUCCESS" "Ping successful!"
            return 0
        else
            log "ERROR" "Ping failed."
            return 1
        fi
    fi
}
