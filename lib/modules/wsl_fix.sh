#!/bin/bash
# ProxySet Module - WSL Fixes
# Targeted at fixing common WSL2 networking issues

module_wsl_fix_set() {
    if ! is_wsl; then return; fi
    
    log "INFO" "Applying Deep WSL network fixes..."
    
    # Fix MTU
    if check_sudo; then
        log "INFO" "Setting MTU to 1400 on eth0..."
        sudo ip link set dev eth0 mtu 1400 || log "WARN" "Failed to set MTU"
    fi

    # Fix DNS / resolv.conf (Disable auto-generation if it's broken)
    if check_sudo; then
        if [[ ! -f /etc/wsl.conf ]] || ! grep -q "generateResolvConf" /etc/wsl.conf; then
            log "INFO" "Configuring /etc/wsl.conf to prevent resolv.conf overwrite..."
            cat <<EOF | sudo tee -a /etc/wsl.conf > /dev/null
[network]
generateResolvConf = false
EOF
        fi
        
        log "INFO" "Setting custom nameserver to Windows Host IP..."
        local host_ip
        host_ip=$(get_wsl_host_ip)
        if [[ -n "$host_ip" ]]; then
            sudo rm -f /etc/resolv.conf
            echo "nameserver $host_ip" | sudo tee /etc/resolv.conf > /dev/null
        fi
    fi
}

module_wsl_fix_unset() {
    if ! is_wsl; then return; fi
    log "INFO" "Resetting WSL network settings..."
    if check_sudo; then
        sudo ip link set dev eth0 mtu 1500 || true
        # We don't necessarily want to revert wsl.conf as it might break things again
        # but we could restore auto-generation if needed.
    fi
}

module_wsl_fix_status() {
    if ! is_wsl; then return; fi
    echo "WSL Specific Info:"
    echo "  Host IP: $(get_wsl_host_ip)"
    echo "  MTU: $(ip link show eth0 | grep -oE "mtu [0-9]+" || echo 'Unknown')"
}
