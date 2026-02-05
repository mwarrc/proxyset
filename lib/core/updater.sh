#!/bin/bash
# ProxySet Core - Updater Module

module_updater_run() {
    local target_version="${1:-}" # Optional: tag, branch, or commit
    local use_proxy="${2:-1}"    # Default: use current proxy settings
    
    log "INFO" "Initializing update sequence..."

    # If proxy bypass is requested, clear environment for the update process
    if [[ "$use_proxy" -eq 0 ]]; then
        log "INFO" "Bypassing proxy for update process..."
        unset http_proxy https_proxy all_proxy no_proxy
        unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
        # Tell git and curl to ignore their local config files
        export GIT_CONFIG_PARAMETERS="http.proxy= https.proxy="
    fi
    
    # 1. Determine installation mode
    if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local repo_root
        repo_root=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
        
        # If no version specified, use current branch
        local branch
        if [[ -z "$target_version" ]]; then
            branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)
        else
            branch="$target_version"
        fi
        
        log "PROGRESS" "Git installation detected [Target: $branch]"
        log "PROGRESS" "Synchronizing with origin..."
        
        if git -C "$repo_root" fetch origin >/dev/null 2>&1; then
            log "INFO" "Resetting codebase to origin/$branch..."
            if git -C "$repo_root" checkout "$branch" && git -C "$repo_root" reset --hard "origin/$branch"; then
                log "SUCCESS" "Update complete. Codebase synchronized to $branch."
            else
                die "Failed to switch to or sync with $branch. Verify the version/branch exists."
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

    # Determine branch from version (defaulting to main for 0.1)
    local target_branch="${target_version:-main}"
    local update_url="https://raw.githubusercontent.com/mwarrc/proxyset/${target_branch}/auto-install.sh"
    
    log "PROGRESS" "Fetching remote distribution from branch '$target_branch'..."
    
    local curl_cmd=("curl" "-sS")
    if [[ "$use_proxy" -eq 0 ]]; then
        curl_cmd+=("-x" "") # This overrides ~/.curlrc and environment
    fi

    if "${curl_cmd[@]}" "$update_url" | bash; then
         log "SUCCESS" "Global update finalized. All modules synchronized."
    else
         die "Critical: Global re-installation failed for branch '$target_branch'."
    fi
}

