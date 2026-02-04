#!/bin/bash
# ProxySet Module - DNS Management
# Handles system-wide DNS to prevent leaks

module_dns_set() {
    local proxy_url="$1"
    log "INFO" "Configuring secure DNS to prevent leaks..."

    if ! check_sudo; then
        log "WARN" "Sudo required for DNS configuration. Skipping."
        return 1
    fi

    # Backup current resolv.conf if not already backed up
    if [[ ! -f "$DATA_DIR/resolv.conf.bak" ]]; then
        cp /etc/resolv.conf "$DATA_DIR/resolv.conf.bak"
    fi

    # Option 1: Systemd-resolved (Modern Linux)
    if command_exists systemd-resolve || command_exists resolvectl; then
        log "INFO" "Applying DNS via systemd-resolved (Cloudflare/Google)..."
        sudo resolvectl dns eth0 1.1.1.1 8.8.8.8 2>/dev/null || true
        sudo resolvectl domain eth0 "~." 2>/dev/null || true
    fi

    # Option 2: Direct resolv.conf (Legacy/Fallthrough)
    log "INFO" "Updating /etc/resolv.conf..."
    cat <<EOF | sudo tee /etc/resolv.conf > /dev/null
# ProxySet Managed DNS
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0 trust-ad
EOF

    log "SUCCESS" "DNS leak protection active."
}

module_dns_unset() {
    log "INFO" "Restoring system DNS..."
    if [[ -f "$DATA_DIR/resolv.conf.bak" ]]; then
        sudo cp "$DATA_DIR/resolv.conf.bak" /etc/resolv.conf
    fi
    
    if command_exists resolvectl; then
        sudo resolvectl revert eth0 2>/dev/null || true
    fi
}

module_dns_status() {
    echo "DNS Status:"
    grep "nameserver" /etc/resolv.conf | head -n 2
}
