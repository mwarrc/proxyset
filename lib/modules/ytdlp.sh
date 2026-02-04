#!/bin/bash
# ProxySet Module - yt-dlp / youtube-dl

module_ytdlp_set() {
    local proxy_url="$1"
    if ! command_exists yt-dlp && ! command_exists youtube-dl; then return 0; fi
    
    # yt-dlp reads /etc/yt-dlp.conf or ~/.config/yt-dlp/config
    local config_dir="$HOME/.config/yt-dlp"
    mkdir -p "$config_dir"
    local config_file="$config_dir/config"
    
    log "INFO" "Configuring yt-dlp..."
    if [[ -f "$config_file" ]]; then
       sed -i '/^--proxy/d' "$config_file"
    fi
    echo "--proxy $proxy_url" >> "$config_file"
    
    log "SUCCESS" "yt-dlp configured in $config_file"
}

module_ytdlp_unset() {
    local config_file="$HOME/.config/yt-dlp/config"
    if [[ -f "$config_file" ]]; then
        sed -i '/^--proxy/d' "$config_file"
        log "SUCCESS" "yt-dlp proxy removed"
    fi
}

module_ytdlp_status() {
    if ! command_exists yt-dlp; then return 0; fi
    echo "yt-dlp:"
    [[ -f "$HOME/.config/yt-dlp/config" ]] && grep "proxy" "$HOME/.config/yt-dlp/config" || echo "  Not configured"
}
