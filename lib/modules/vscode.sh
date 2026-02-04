#!/bin/bash
# ProxySet Module - VS Code

module_vscode_set() {
    local proxy_url="$1"
    local settings_file="$HOME/.config/Code/User/settings.json"
    
    if [[ -d "$(dirname "$settings_file")" ]]; then
        log "INFO" "Configuring VS Code proxy..."
        if command_exists jq; then
            if [[ -f "$settings_file" ]]; then
                cat "$settings_file" | jq --arg p "$proxy_url" '."http.proxy" = $p' > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
            else
                echo "{\"http.proxy\": \"$proxy_url\"}" > "$settings_file"
            fi
        else
            log "WARN" "jq not found. Cannot safely update VS Code settings.json"
        fi
    fi
}

module_vscode_unset() {
    local settings_file="$HOME/.config/Code/User/settings.json"
    if [[ -f "$settings_file" ]] && command_exists jq; then
        log "INFO" "Removing VS Code proxy..."
        cat "$settings_file" | jq 'del(."http.proxy")' > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
    fi
}

module_vscode_status() {
    local settings_file="$HOME/.config/Code/User/settings.json"
    if [[ -f "$settings_file" ]]; then
        echo "VS Code Settings:"
        grep "http.proxy" "$settings_file" || echo "  No proxy set"
    fi
}
