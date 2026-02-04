#!/bin/bash
# ProxySet Core - Updater Module

module_updater_run() {
    log "INFO" "Initializing update sequence..."
    
    # 1. Determine installation mode
    # Check if we are inside a git work tree
    if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local repo_root
        repo_root=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
        local branch
        branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)
        
        log "PROGRESS" "Git installation detected [Branch: $branch]"
        log "PROGRESS" "Synchronizing with origin..."
        
        if git -C "$repo_root" fetch origin "$branch" >/dev/null 2>&1; then
            local loc rem
            loc=$(git -C "$repo_root" rev-parse HEAD)
            rem=$(git -C "$repo_root" rev-parse "origin/$branch")
            
            if [[ "$loc" == "$rem" ]]; then
                log "SUCCESS" "System is already at the latest revision."
            else
                log "WARN" "New revision found. Converging code..."
                if git -C "$repo_root" pull origin "$branch"; then
                    log "SUCCESS" "Update complete. Codebase synchronized."
                else
                    die "Failed to pull remote changes. Check your network or local modifications."
                fi
            fi
        else
            die "Failed to reach remote repository. Verify internet connectivity."
        fi
        return 0
    fi

    # 2. Global Installation Mode
    log "INFO" "Global installation detected. Initiating remote re-install..."
    
    if ! command_exists curl; then
        die "Dependencies missing: 'curl' is required for global updates."
    fi

    # Determine branch from version (defaulting to testing for Alpha 3.0)
    local update_url="https://raw.githubusercontent.com/mwarrc/proxyset/testing/auto-install.sh"
    
    log "PROGRESS" "Fetching remote distribution from: $update_url"
    if curl -sS "$update_url" | bash; then
         log "SUCCESS" "Global update finalized. All modules synchronized."
    else
         die "Critical: Global re-installation failed."
    fi
}
