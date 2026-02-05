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
    
    # Ensure current dir has what we need
    if [[ ! -f proxyset.sh || ! -d lib ]]; then
        die "Installer must be run from the root of the ProxySet repository."
    fi

    log "PROGRESS" "Creating system directories..."
    run_sudo mkdir -p "$config_path/lib/core"
    run_sudo mkdir -p "$config_path/lib/modules"
    run_sudo mkdir -p "$config_path/completions"
    
    log "PROGRESS" "Copying files to $config_path..."
    run_sudo cp -r lib/core/* "$config_path/lib/core/"
    run_sudo cp -r lib/modules/* "$config_path/lib/modules/"
    [[ -d completions ]] && run_sudo cp -r completions/* "$config_path/completions/"
    
    log "PROGRESS" "Creating global executable at $install_path..."
    # Create a wrapper script or copy the main one with adjusted paths
    cat <<EOF | run_sudo tee "$install_path" > /dev/null
#!/bin/bash
# ProxySet Global Wrapper
export PROXYSET_ROOT="$config_path"
bash "\$PROXYSET_ROOT/proxyset.sh" "\$@"
EOF

    # Copy the main script to the config path as well
    run_sudo cp proxyset.sh "$config_path/proxyset.sh"
    
    run_sudo chmod +x "$install_path"
    run_sudo chmod +x "$config_path/proxyset.sh"
    
    # Install completions
    if [[ -d "/usr/share/bash-completion/completions" ]]; then
        run_sudo cp completions/proxyset.bash "/usr/share/bash-completion/completions/proxyset"
        log "PROGRESS" "Installed bash completions."
    fi
    
    log "SUCCESS" "ProxySet installed successfully! You can now run 'proxyset' from anywhere."
}

_installer_uninstall() {
    log "INFO" "Uninstalling ProxySet..."
    
    run_sudo rm -f "/usr/local/bin/proxyset"
    run_sudo rm -rf "/usr/local/lib/proxyset"
    run_sudo rm -f "/usr/share/bash-completion/completions/proxyset"
    
    log "SUCCESS" "ProxySet uninstalled."
}
