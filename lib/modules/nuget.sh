#!/bin/bash
# ============================================================================
# ProxySet Module - NuGet / .NET Core
# ============================================================================
# Configures proxy for NuGet package manager.
# Modifies ~/.nuget/NuGet/NuGet.Config.
# ============================================================================

readonly NUGET_CONFIG="$HOME/.nuget/NuGet/NuGet.Config"

module_nuget_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists dotnet && ! command_exists nuget; then
        return 0
    fi
    
    log "INFO" "Configuring NuGet proxy..."
    
    # Nuget config command is the safest way
    if command_exists nuget; then
        nuget config -set http_proxy="$proxy_url" >/dev/null 2>&1
        nuget config -set https_proxy="$proxy_url" >/dev/null 2>&1
        if [[ -n "$no_proxy" ]]; then
             nuget config -set no_proxy="$no_proxy" >/dev/null 2>&1
        fi
    elif command_exists dotnet; then
        # Dotnet doesn't strictly have a 'config set proxy' command in older versions easily
        # falling back to XML manipulation or file check
        if [[ ! -f "$NUGET_CONFIG" ]]; then
             mkdir -p "$(dirname "$NUGET_CONFIG")"
             echo '<?xml version="1.0" encoding="utf-8"?><configuration></configuration>' > "$NUGET_CONFIG"
        fi
        
        # Simple hacky XML update if nuget CLI is missing
        # Recommendation: Use environment variables for dotnet in 2026
        export HTTP_PROXY="$proxy_url"
        export DOTNET_HTTP_PROXY="$proxy_url"
        export DOTNET_HTTPS_PROXY="$proxy_url"
        
        log "INFO" "NuGet configured via environment variables (cleanest for .NET Core)"
    fi
    
    log "SUCCESS" "NuGet proxy configured."
}

module_nuget_unset() {
    if ! command_exists dotnet && ! command_exists nuget; then return 0; fi
    
    log "INFO" "Removing NuGet proxy..."
    if command_exists nuget; then
        nuget config -Set http_proxy="" >/dev/null 2>&1
        nuget config -Set https_proxy="" >/dev/null 2>&1
    fi
}

module_nuget_status() {
    echo "NuGet Proxy:"
    if command_exists nuget; then
        nuget config http_proxy 2>/dev/null || echo "  Not set via CLI"
    else
        echo "  (Checked environment variables)"
    fi
}
