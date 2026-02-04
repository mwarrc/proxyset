#!/bin/bash
# ProxySet Module - Environment Variables

module_env_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    log "INFO" "Setting environment variables (Session & Persistent)..."
    
    # Current session
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    export ftp_proxy="$proxy_url"
    export all_proxy="$proxy_url"
    export no_proxy="$no_proxy"
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export FTP_PROXY="$proxy_url"
    export ALL_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    
    # SOCKS specific variables
    if [[ "$proxy_url" =~ ^socks ]]; then
        export socks_proxy="$proxy_url"
        export SOCKS_PROXY="$proxy_url"
        export all_proxy="$proxy_url"
        export ALL_PROXY="$proxy_url"
    fi

    # Persistent - User (.bashrc)
    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$HOME/.bashrc"
        cat >> "$HOME/.bashrc" <<EOF
# ProxySet Start
export http_proxy="$proxy_url"
export https_proxy="$proxy_url"
export all_proxy="$proxy_url"
export no_proxy="$no_proxy"
export HTTP_PROXY="$proxy_url"
export HTTPS_PROXY="$proxy_url"
export ALL_PROXY="$proxy_url"
export NO_PROXY="$no_proxy"
# ProxySet End
EOF
    fi

    # Persistent - System (/etc/environment)
    if check_sudo; then
        sudo sed -i '/http_proxy=/d;/https_proxy=/d;/all_proxy=/d;/no_proxy=/d;/HTTP_PROXY=/d;/HTTPS_PROXY=/d;/ALL_PROXY=/d;/NO_PROXY=/d' /etc/environment
        echo "http_proxy=\"$proxy_url\"" | sudo tee -a /etc/environment > /dev/null
        echo "https_proxy=\"$proxy_url\"" | sudo tee -a /etc/environment > /dev/null
        echo "no_proxy=\"$no_proxy\"" | sudo tee -a /etc/environment > /dev/null
    fi
}

module_env_unset() {
    log "INFO" "Unsetting environment variables..."
    unset http_proxy https_proxy ftp_proxy all_proxy no_proxy
    unset HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY

    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i '/# ProxySet Start/,/# ProxySet End/d' "$HOME/.bashrc"
    fi

    if check_sudo; then
        sudo sed -i '/http_proxy=/d;/https_proxy=/d;/all_proxy=/d;/no_proxy=/d;/HTTP_PROXY=/d;/HTTPS_PROXY=/d;/ALL_PROXY=/d;/NO_PROXY=/d' /etc/environment
    fi
}

module_env_status() {
    echo "Environment Variables:"
    # Check live session
    if env | grep -iE "(_proxy|PROXY)=" > /dev/null; then
        env | grep -iE "(_proxy|PROXY)=" | sed 's/^/  [Live] /'
    fi
    
    # Check persistent config
    if [[ -f "$HOME/.bashrc" ]] && grep -q "# ProxySet Start" "$HOME/.bashrc"; then
        echo "  [Persistent] Configured in ~/.bashrc"
    fi
    
    if [[ -f "/etc/environment" ]] && grep -qiE "(_proxy|PROXY)=" "/etc/environment"; then
        echo "  [Persistent] Configured in /etc/environment"
    fi
}
