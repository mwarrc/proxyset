#!/bin/bash
# ProxySet Module - Docker
# Deep configuration for Docker client and daemon

module_docker_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if command_exists docker; then
        log "INFO" "Configuring Docker Client proxy (~/.docker/config.json)..."
        
        local docker_conf="$HOME/.docker/config.json"
        mkdir -p "$(dirname "$docker_conf")"
        
        # We'll use a simple approach to manage the JSON if jq is available
        if command_exists jq; then
            if [[ -f "$docker_conf" ]]; then
                cat "$docker_conf" | jq --arg p "$proxy_url" --arg no "$no_proxy" \
                '.proxies.default.httpProxy = $p | .proxies.default.httpsProxy = $p | .proxies.default.noProxy = $no' \
                > "${docker_conf}.tmp" && mv "${docker_conf}.tmp" "$docker_conf"
            else
                echo "{\"proxies\":{\"default\":{\"httpProxy\":\"$proxy_url\",\"httpsProxy\":\"$proxy_url\",\"noProxy\":\"$no_proxy\"}}}" > "$docker_conf"
            fi
        else
            log "WARN" "jq not found. Cannot safely edit Docker config.json. Use manual setup or install jq."
        fi
        
        log "INFO" "Configuring Docker Daemon proxy (systemd)..."
        if check_sudo; then
            local dropin_dir="/etc/systemd/system/docker.service.d"
            sudo mkdir -p "$dropin_dir"
            cat <<EOF | sudo tee "$dropin_dir/http-proxy.conf" > /dev/null
[Service]
Environment="HTTP_PROXY=$proxy_url"
Environment="HTTPS_PROXY=$proxy_url"
Environment="NO_PROXY=$no_proxy"
EOF
            sudo systemctl daemon-reload
            log "SUCCESS" "Docker Daemon proxy configured. Restart docker for changes to take effect: sudo systemctl restart docker"
        else
            log "WARN" "Sudo required to configure Docker Daemon proxy. Skipping."
        fi
    fi
}

module_docker_unset() {
    if [[ -f "$HOME/.docker/config.json" ]]; then
        log "INFO" "Removing Docker Client proxy..."
        if command_exists jq; then
             cat "$HOME/.docker/config.json" | jq 'del(.proxies.default)' > "$HOME/.docker/config.json.tmp" && mv "$HOME/.docker/config.json.tmp" "$HOME/.docker/config.json"
        else
            log "WARN" "jq not found. Manual intervention required to clean Docker config.json"
        fi
    fi
}

module_docker_status() {
    if [[ -f "$HOME/.docker/config.json" ]]; then
        echo "Docker Client Config:"
        cat "$HOME/.docker/config.json" | grep -iE "(httpProxy|httpsProxy|noProxy)" || echo "  No proxy set"
    fi
}
