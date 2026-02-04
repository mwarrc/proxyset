#!/bin/bash
# ProxySet Module - DNF (Fedora/RHEL)

module_dnf_set() {
    local proxy_url="$1"
    if command_exists dnf; then
        log "INFO" "Configuring DNF proxy in /etc/dnf/dnf.conf..."
        if check_sudo; then
            # Remove existing proxy line and add new one
            sudo sed -i '/^proxy=/d' /etc/dnf/dnf.conf
            echo "proxy=$proxy_url" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
        else
            log "WARN" "Sudo required to configure DNF. Skipping."
        fi
    fi
}

module_dnf_unset() {
    if command_exists dnf; then
        log "INFO" "Removing DNF proxy from /etc/dnf/dnf.conf..."
        if check_sudo; then
            sudo sed -i '/^proxy=/d' /etc/dnf/dnf.conf
        else
            log "WARN" "Sudo required to remove DNF proxy. Skipping."
        fi
    fi
}

module_dnf_status() {
    if command_exists dnf; then
        echo "DNF Proxy:"
        grep "^proxy=" /etc/dnf/dnf.conf || echo "  Not set"
    fi
}
