#!/bin/bash
# ProxySet Module - XFCE / LXDE / LXQt / MATE / Cinnamon
# These desktops often respect GTK settings or standard environment variables.
# For XFCE, uses xfconf-query if available.

module_xfce_set() {
    local proxy_url="$1"
    # Basic xfconf manipulation if needed
    if command_exists xfconf-query; then
        # Parse host/port
        local proxy_data
        proxy_data=$(parse_proxy_url "$proxy_url")
        IFS='|' read -r proto user pass host port <<< "$proxy_data"
        
        # XFCE (libproxy) settings
        xfconf-query -c xfce4-session -p /sessions/Failsafe/Client0_Command -t string -s "env http_proxy=$proxy_url" 2>/dev/null || true
        # Also just exporting standard env vars covers 90%
        # Real Gnome/GTK apps read dconf/gsettings, effectively covered by desktop.sh if using GNOME stack
        log "INFO" "XFCE settings updated (best effort)"
    fi
}

module_xfce_unset() {
    true # No-op mostly, reliant on env module
}

module_xfce_status() {
    echo "XFCE: See env module"
}
