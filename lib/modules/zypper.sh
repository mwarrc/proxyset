#!/bin/bash
# ProxySet Module - Zypper (openSUSE)

module_zypper_set() {
    local proxy_url="$1"
    if command_exists zypper; then
        log "INFO" "Configuring Zypper proxy settings..."
        # Zypper uses /etc/sysconfig/proxy on SUSE
        if [[ -f /etc/sysconfig/proxy ]] && check_sudo; then
            sudo sed -i "s|^PROXY_ENABLED=.*|PROXY_ENABLED=\"yes\"|" /etc/sysconfig/proxy
            sudo sed -i "s|^HTTP_PROXY=.*|HTTP_PROXY=\"$proxy_url\"|" /etc/sysconfig/proxy
            sudo sed -i "s|^HTTPS_PROXY=.*|HTTPS_PROXY=\"$proxy_url\"|" /etc/sysconfig/proxy
        else
            log "WARN" "Sudo required or /etc/sysconfig/proxy not found. Skipping Zypper config."
        fi
    fi
}

module_zypper_unset() {
    if command_exists zypper && [[ -f /etc/sysconfig/proxy ]] && check_sudo; then
        log "INFO" "Disabling Zypper proxy..."
        sudo sed -i "s|^PROXY_ENABLED=.*|PROXY_ENABLED=\"no\"|" /etc/sysconfig/proxy
    fi
}

module_zypper_status() {
    if [[ -f /etc/sysconfig/proxy ]]; then
        echo "Zypper (SUSE) Proxy:"
        grep -E "^(PROXY_ENABLED|HTTP_PROXY)=" /etc/sysconfig/proxy
    fi
}
