#!/bin/bash
# ProxySet Module - PAC (Proxy Auto-Config)

module_pac_set() {
    local pac_url="$1"
    log "INFO" "Configuring Proxy Auto-Config (PAC) URL: $pac_url"
    
    # GNOME
    if command_exists gsettings; then
        log "INFO" "Setting GNOME PAC..."
        gsettings set org.gnome.system.proxy mode 'auto'
        gsettings set org.gnome.system.proxy autoconfig-url "$pac_url"
    fi
    
    # Export for browsers that check it
    export auto_proxy="$pac_url"
    
    # Persistent .bashrc
    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i '/# ProxySet PAC Start/,/# ProxySet PAC End/d' "$HOME/.bashrc"
        echo "# ProxySet PAC Start" >> "$HOME/.bashrc"
        echo "export auto_proxy=\"$pac_url\"" >> "$HOME/.bashrc"
        echo "# ProxySet PAC End" >> "$HOME/.bashrc"
    fi
}

module_pac_unset() {
    if command_exists gsettings; then
        gsettings set org.gnome.system.proxy mode 'none'
        gsettings set org.gnome.system.proxy autoconfig-url ''
    fi
    
    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i '/# ProxySet PAC Start/,/# ProxySet PAC End/d' "$HOME/.bashrc"
    fi
}

module_pac_status() {
    if command_exists gsettings; then
        echo "GNOME PAC URL: $(gsettings get org.gnome.system.proxy autoconfig-url)"
    fi
    echo "Environment auto_proxy: ${auto_proxy:-Not set}"
}
