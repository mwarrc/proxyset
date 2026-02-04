#!/bin/bash
# ProxySet Module - Gentoo Portage (emerge)

readonly MAKE_CONF="/etc/portage/make.conf"

module_emerge_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    if ! command_exists emerge; then return 0; fi
    
    log "INFO" "Configuring Portage..."
    if ! check_sudo; then log "WARN" "Sudo required."; return 1; fi
    
    if [[ -f "$MAKE_CONF" ]]; then
         # Portage respects http_proxy / ftp_proxy in make.conf
         # We need to replace or append
         # Removing old
         sudo sed -i '/^http_proxy/d' "$MAKE_CONF"
         sudo sed -i '/^https_proxy/d' "$MAKE_CONF"
         sudo sed -i '/^ftp_proxy/d' "$MAKE_CONF"
         
         # Appending new
         echo "http_proxy=\"$proxy_url\"" | sudo tee -a "$MAKE_CONF" > /dev/null
         echo "https_proxy=\"$proxy_url\"" | sudo tee -a "$MAKE_CONF" > /dev/null
         echo "ftp_proxy=\"$proxy_url\"" | sudo tee -a "$MAKE_CONF" > /dev/null
         
         log "SUCCESS" "Portage configured in $MAKE_CONF"
    else
         log "WARN" "$MAKE_CONF not found."
    fi
}

module_emerge_unset() {
    if ! command_exists emerge; then return 0; fi
    if check_sudo && [[ -f "$MAKE_CONF" ]]; then
        sudo sed -i '/^http_proxy/d' "$MAKE_CONF"
        sudo sed -i '/^https_proxy/d' "$MAKE_CONF"
        sudo sed -i '/^ftp_proxy/d' "$MAKE_CONF"
        log "SUCCESS" "Portage proxy removed"
    fi
}

module_emerge_status() {
    if ! command_exists emerge; then return 0; fi
    echo "Portage (emerge):"
    [[ -f "$MAKE_CONF" ]] && grep "proxy" "$MAKE_CONF" || echo "  Not configured"
}
