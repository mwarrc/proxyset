#!/bin/bash
# ProxySet Module - Desktop Environments (GNOME/KDE)

module_desktop_set() {
    local proxy_url="$1"
    
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r type user pass host port <<< "$proxy_data"

    # GNOME
    if command_exists gsettings; then
        log "INFO" "Configuring GNOME proxy settings..."
        gsettings set org.gnome.system.proxy mode 'manual'
        gsettings set org.gnome.system.proxy.http host "$host"
        gsettings set org.gnome.system.proxy.http port "$port"
        gsettings set org.gnome.system.proxy.https host "$host"
        gsettings set org.gnome.system.proxy.https port "$port"
    fi

    # KDE
    if command_exists kwriteconfig5; then
        log "INFO" "Configuring KDE proxy settings..."
        kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "ProxyType" 1
        kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "httpProxy" "$proxy_url"
        kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "httpsProxy" "$proxy_url"
    fi
}

module_desktop_unset() {
    if command_exists gsettings; then
        log "INFO" "Resetting GNOME proxy settings..."
        gsettings set org.gnome.system.proxy mode 'none'
    fi

    if command_exists kwriteconfig5; then
        log "INFO" "Resetting KDE proxy settings..."
        kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "ProxyType" 0
    fi
}

module_desktop_status() {
    echo "Desktop Environment Proxy:"
    if command_exists gsettings; then
        echo "  GNOME Mode: $(gsettings get org.gnome.system.proxy mode)"
    fi
    if command_exists kwriteconfig5; then
        echo "  KDE Proxy: $(kreadconfig5 --file kioslaverc --group "Proxy Settings" --key "httpProxy" 2>/dev/null || echo 'Not set')"
    fi
}
