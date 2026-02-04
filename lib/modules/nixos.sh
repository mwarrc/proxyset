#!/bin/bash
# ProxySet Module - NixOS
# Note: NixOS is immutable. We provide instructions or session-level env vars.

module_nixos_set() {
    if [[ ! -f /etc/NIXOS ]]; then return; fi
    
    log "WARN" "NixOS detected. System-wide changes must be made in /etc/nixos/configuration.nix"
    log "INFO" "Setting session-level variables for the current user..."
    
    # We can at least create a shell fragment for the user to source
    local fragment="$CONFIG_DIR/nix_proxy.sh"
    cat <<EOF > "$fragment"
export http_proxy="$1"
export https_proxy="$1"
export all_proxy="$1"
export no_proxy="$2"
EOF
    log "SUCCESS" "Created Nix-compatible env fragment: $fragment"
    log "INFO" "To apply permanently, add 'networking.proxy.default = \"$1\";' to configuration.nix"
}

module_nixos_unset() {
    local fragment="$CONFIG_DIR/nix_proxy.sh"
    rm -f "$fragment"
}

module_nixos_status() {
    if [[ -f /etc/NIXOS ]]; then
        echo "NixOS detected. Standard 'env' module may work for users, but system rebuild is recommended for permanency."
    fi
}
