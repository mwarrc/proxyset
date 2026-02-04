#!/bin/bash
# ProxySet Module - Gentoo (Portage)

module_gentoo_set() {
    local proxy_url="$1"
    if [[ -f /etc/portage/make.conf ]]; then
        log "INFO" "Configuring Gentoo Portage proxy in make.conf..."
        if check_sudo; then
            sudo sed -i '/^http_proxy=/d' /etc/portage/make.conf
            sudo sed -i '/^https_proxy=/d' /etc/portage/make.conf
            sudo sed -i '/^ftp_proxy=/d' /etc/portage/make.conf
            echo "http_proxy=\"$proxy_url\"" | sudo tee -a /etc/portage/make.conf > /dev/null
            echo "https_proxy=\"$proxy_url\"" | sudo tee -a /etc/portage/make.conf > /dev/null
            echo "ftp_proxy=\"$proxy_url\"" | sudo tee -a /etc/portage/make.conf > /dev/null
        else
            log "WARN" "Sudo required for Gentoo config. Skipping."
        fi
    fi
}

module_gentoo_unset() {
    if [[ -f /etc/portage/make.conf ]] && check_sudo; then
        log "INFO" "Removing Portage proxy from make.conf..."
        sudo sed -i '/^http_proxy=/d' /etc/portage/make.conf
        sudo sed -i '/^https_proxy=/d' /etc/portage/make.conf
        sudo sed -i '/^ftp_proxy=/d' /etc/portage/make.conf
    fi
}

module_gentoo_status() {
    if [[ -f /etc/portage/make.conf ]]; then
        echo "Gentoo Portage Proxy:"
        grep -E "^(http_proxy|https_proxy)=" /etc/portage/make.conf || echo "  Not set"
    fi
}
