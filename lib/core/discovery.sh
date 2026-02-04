#!/bin/bash
# ============================================================================
# ProxySet Core - Network Auto-Discovery (WPAD)
# ============================================================================
# Attempts to automatically detect proxy settings using:
# 1. DNS WPAD conventions (wpad.domain.local/wpad.dat)
# 2. Existing environment variables
# 3. GNOME/KDE system settings
# ============================================================================

# Attempt to discover proxy settings
run_discovery() {
    log "INFO" "Starting network proxy auto-discovery..."
    
    local found_proxy=""
    local discovery_source=""
    
    # 1. Check Desktop Environment Settings (Most reliable for user desktops)
    if [[ -z "$found_proxy" ]] && command_exists gsettings; then
        local gnome_mode
        gnome_mode=$(gsettings get org.gnome.system.proxy mode 2>/dev/null | tr -d "'")
        if [[ "$gnome_mode" == "manual" ]]; then
            local host port
            host=$(gsettings get org.gnome.system.proxy.http host 2>/dev/null | tr -d "'")
            port=$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)
            if [[ -n "$host" && "$port" != "0" ]]; then
                found_proxy="http://${host}:${port}"
                discovery_source="GNOME Settings"
            fi
        fi
    fi
    
    # 2. Check WPAD via DNS
    if [[ -z "$found_proxy" ]]; then
        log "INFO" "Checking DNS for WPAD..."
        local domain
        domain=$(hostname -d 2>/dev/null)
        if [[ -n "$domain" ]]; then
            local wpad_url="http://wpad.${domain}/wpad.dat"
            if curl --connect-timeout 2 -sI "$wpad_url" | grep -q "200 OK"; then
                log "SUCCESS" "Found WPAD PAC file at: $wpad_url"
                echo ""
                echo "Proxy Auto-Config (PAC) found."
                echo "To configure, run: proxyset pac set $wpad_url"
                return 0
            fi
        fi
    fi
    
    # 3. Check for common environment variables in typical config files
    if [[ -z "$found_proxy" ]]; then
        local potential_files=("/etc/environment" "/etc/profile.d/proxy.sh" "/etc/wgetrc")
        for file in "${potential_files[@]}"; do
            if [[ -f "$file" ]]; then
                local match
                match=$(grep -i "http_proxy" "$file" | head -n 1 | cut -d= -f2 | tr -d '"' | tr -d "'")
                if [[ -n "$match" ]]; then
                    found_proxy="$match"
                    discovery_source="System Config ($file)"
                    break
                fi
            fi
        done
    fi
    
    # Report Findings
    if [[ -n "$found_proxy" ]]; then
        log "SUCCESS" "Proxy Discovered via $discovery_source!"
        echo ""
        echo "Detected Proxy: $found_proxy"
        echo ""
        read -p "Do you want to apply this proxy now? [y/N]: " apply
        if [[ "$apply" =~ ^[Yy]$ ]]; then
            # Parse it to feed into the set command
            # Assume http for now if protocol missing
            if [[ "$found_proxy" != *"://"* ]]; then
                found_proxy="http://$found_proxy"
            fi
            
            local host port proto
            local clean_url="${found_proxy#*://}" # remove protocol
            host="${clean_url%%:*}"
            port="${clean_url##*:}"
            port="${port%%/*}" # strict port
            
            # Simple validation to ensure we have a valid port
            if [[ ! "$port" =~ ^[0-9]+$ ]]; then
               # Fallback if parsing failed
               run_module_cmd "set" "$found_proxy" ""
            else
               run_module_cmd "set" "$found_proxy" ""
            fi
        fi
    else
        log "WARN" "No proxy settings automatically discovered."
        echo "Try checking with your network administrator or enter settings manually:"
        echo "  proxyset wizard"
    fi
}
