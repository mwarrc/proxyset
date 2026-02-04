#!/bin/bash
# ProxySet Module - APK (Alpine Linux)

module_apk_set() {
    local proxy_url="$1"
    if command_exists apk; then
        log "INFO" "Configuring APK proxy in /etc/apk/repositories..."
        # Note: APK doesn't have a direct 'proxy' config in apk.conf, 
        # it relies on environment variables or --proxy flag.
        # However, some people use a custom file or env file.
        # We can also handle it via /etc/profile.d/ if not already covered.
        log "DEBUG" "APK follows system environment variables (http_proxy)."
    fi
}

module_apk_unset() {
    : # Standard env unset covers apk usually
}

module_apk_status() {
    if command_exists apk; then
        echo "APK (Alpine):"
        echo "  Usage: Follows system environment variables (http_proxy)."
    fi
}
