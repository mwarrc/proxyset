#!/bin/bash
# ProxySet Core - Installer Module

module_installer_run() {
    local action="${1:-install}"
    
    if [[ "$action" == "uninstall" ]]; then
        _installer_uninstall
        return
    fi

    log "INFO" "Starting ProxySet Global Installation..."
    
    local install_path="/usr/local/bin/proxyset"
    local config_path="/usr/local/lib/proxyset"
    
    if ! check_sudo; then
        die "Sudo privileges are required to install ProxySet globally."
    fi
    
    log "PROGRESS" "Creating system directories..."
    sudo mkdir -p "$config_path/lib/core"
    sudo mkdir -p "$config_path/lib/modules"
    sudo mkdir -p "$config_path/completions"
    
    log "PROGRESS" "Copying files to $config_path..."
    sudo cp -r lib/core/* "$config_path/lib/core/"
    sudo cp -r lib/modules/* "$config_path/lib/modules/"
    [[ -d completions ]] && sudo cp -r completions/* "$config_path/completions/"
    
    log "PROGRESS" "Creating global executable at $install_path..."
    # Create a wrapper script or copy the main one with adjusted paths
    cat <<EOF | sudo tee "$install_path" > /dev/null
#!/bin/bash
# ProxySet Global Wrapper
export PROXYSET_ROOT="$config_path"
bash "\$PROXYSET_ROOT/proxyset.sh" "\$@"
EOF

    # Copy the main script to the config path as well
    sudo cp proxyset.sh "$config_path/proxyset.sh"
    
    sudo chmod +x "$install_path"
    sudo chmod +x "$config_path/proxyset.sh"
    
    # Install completions
    if [[ -d "/usr/share/bash-completion/completions" ]]; then
        sudo cp completions/proxyset.bash "/usr/share/bash-completion/completions/proxyset"
        log "PROGRESS" "Installed bash completions."
    fi
    
    log "SUCCESS" "ProxySet installed successfully! You can now run 'proxyset' from anywhere."
}

_installer_uninstall() {
    log "INFO" "Uninstalling ProxySet..."
    if ! check_sudo; then die "Sudo required."; fi
    
    sudo rm -f "/usr/local/bin/proxyset"
    sudo rm -rf "/usr/local/lib/proxyset"
    sudo rm -f "/usr/share/bash-completion/completions/proxyset"
    
    log "SUCCESS" "ProxySet uninstalled."
}
