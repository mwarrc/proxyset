#!/bin/bash
# ProxySet Module - Python (PIP)

module_pip_set() {
    local proxy_url="$1"
    if command_exists pip || command_exists pip3; then
        log "INFO" "Configuring PIP proxy..."
        mkdir -p "$HOME/.pip"
        cat > "$HOME/.pip/pip.conf" <<EOF
[global]
proxy = $proxy_url
EOF
    fi
}

module_pip_unset() {
    if [[ -f "$HOME/.pip/pip.conf" ]]; then
        log "INFO" "Removing PIP proxy..."
        rm "$HOME/.pip/pip.conf"
    fi
}

module_pip_status() {
    if [[ -f "$HOME/.pip/pip.conf" ]]; then
        echo "PIP Proxy:"
        cat "$HOME/.pip/pip.conf"
    else
        echo "PIP Proxy: Not set"
    fi
}
