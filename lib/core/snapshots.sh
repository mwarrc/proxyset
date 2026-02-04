#!/bin/bash
# ============================================================================
# ProxySet Core - Snapshot & Restore Module
# ============================================================================
# Provides comprehensive system state capture and restoration.
# Supports automatic pre-flight backups and manual snapshots.
# ============================================================================

SNAPSHOT_DIR="${DATA_DIR:-$HOME/.local/share/proxyset}/snapshots"

# Maximum number of auto-snapshots to keep
readonly MAX_AUTO_SNAPSHOTS=10

# ----------------------------------------------------------------------------
# Snapshot Creation
# ----------------------------------------------------------------------------

# Take a comprehensive system proxy snapshot
# Usage: take_snapshot [name]
# Creates timestamped snapshot if no name provided
take_snapshot() {
    local name="${1:-snapshot_$(date +%Y%m%d_%H%M%S)}"
    local target="$SNAPSHOT_DIR/$name"
    
    # Prevent overwriting existing snapshots
    if [[ -d "$target" ]]; then
        log "WARN" "Snapshot '$name' already exists. Skipping."
        return 1
    fi
    
    mkdir -p "$target"
    
    log "INFO" "Creating system proxy snapshot: $name"
    
    # Create metadata
    cat > "$target/metadata.json" <<EOF
{
    "name": "$name",
    "created": "$(date -Iseconds)",
    "user": "$(whoami)",
    "hostname": "$(hostname)",
    "proxyset_version": "3.0.0-alpha"
}
EOF
    
    # 1. Environment variables
    env | grep -iE "(proxy|no_proxy)" > "$target/env.txt" 2>/dev/null || true
    
    # 2. Shell profile (bashrc)
    if [[ -f "$HOME/.bashrc" ]]; then
        grep -A 20 "# ProxySet" "$HOME/.bashrc" > "$target/bashrc_proxy.txt" 2>/dev/null || true
    fi
    
    # 3. System environment
    if [[ -f /etc/environment ]]; then
        grep -iE "(proxy|no_proxy)" /etc/environment > "$target/etc_environment.txt" 2>/dev/null || true
    fi
    
    # 4. GNOME settings
    if command_exists gsettings; then
        gsettings list-recursively org.gnome.system.proxy > "$target/gnome_proxy.txt" 2>/dev/null || true
    fi
    
    # 5. APT config
    if [[ -f /etc/apt/apt.conf.d/95proxies ]]; then
        cp /etc/apt/apt.conf.d/95proxies "$target/apt_proxy.conf" 2>/dev/null || true
    fi
    
    # 6. YUM/DNF config
    if [[ -f /etc/yum.conf ]]; then
        grep -E "^proxy" /etc/yum.conf > "$target/yum_proxy.txt" 2>/dev/null || true
    fi
    if [[ -f /etc/dnf/dnf.conf ]]; then
        grep -E "^proxy" /etc/dnf/dnf.conf > "$target/dnf_proxy.txt" 2>/dev/null || true
    fi
    
    # 7. Git config
    if command_exists git; then
        git config --global --get http.proxy > "$target/git_http_proxy.txt" 2>/dev/null || true
        git config --global --get https.proxy > "$target/git_https_proxy.txt" 2>/dev/null || true
    fi
    
    # 8. Docker config
    if [[ -f "$HOME/.docker/config.json" ]]; then
        cp "$HOME/.docker/config.json" "$target/docker_config.json" 2>/dev/null || true
    fi
    if [[ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]]; then
        cp /etc/systemd/system/docker.service.d/http-proxy.conf "$target/docker_daemon_proxy.conf" 2>/dev/null || true
    fi
    
    # 9. NPM config
    if command_exists npm; then
        npm config get proxy > "$target/npm_proxy.txt" 2>/dev/null || true
        npm config get https-proxy > "$target/npm_https_proxy.txt" 2>/dev/null || true
    fi
    
    # 10. SSH config
    if [[ -f "$HOME/.ssh/config" ]]; then
        grep -A 5 "# ProxySet" "$HOME/.ssh/config" > "$target/ssh_proxy.txt" 2>/dev/null || true
    fi
    
    # 11. wget/curl configs
    [[ -f "$HOME/.wgetrc" ]] && cp "$HOME/.wgetrc" "$target/wgetrc" 2>/dev/null || true
    [[ -f "$HOME/.curlrc" ]] && cp "$HOME/.curlrc" "$target/curlrc" 2>/dev/null || true
    
    # 12. Cargo config
    [[ -f "$HOME/.cargo/config.toml" ]] && cp "$HOME/.cargo/config.toml" "$target/cargo_config.toml" 2>/dev/null || true
    
    log "SUCCESS" "Snapshot saved: $target"
    
    # Cleanup old auto-snapshots
    _cleanup_auto_snapshots
}

# ----------------------------------------------------------------------------
# Snapshot Restoration
# ----------------------------------------------------------------------------

# Restore system state from a snapshot
# Usage: restore_snapshot <name>
restore_snapshot() {
    local name="$1"
    local source="$SNAPSHOT_DIR/$name"
    
    if [[ -z "$name" ]]; then
        log "ERROR" "Snapshot name required"
        return 1
    fi
    
    if [[ ! -d "$source" ]]; then
        log "ERROR" "Snapshot '$name' not found"
        return 1
    fi
    
    log "INFO" "Restoring from snapshot: $name"
    
    # Take a pre-restore snapshot first
    take_snapshot "pre_restore_$(date +%Y%m%d_%H%M%S)"
    
    # 1. Restore Git config
    if [[ -f "$source/git_http_proxy.txt" ]] && command_exists git; then
        local git_proxy
        git_proxy=$(cat "$source/git_http_proxy.txt" 2>/dev/null)
        if [[ -n "$git_proxy" ]]; then
            git config --global http.proxy "$git_proxy"
            log "INFO" "Restored Git HTTP proxy"
        fi
    fi
    
    # 2. Restore Docker client config
    if [[ -f "$source/docker_config.json" ]]; then
        mkdir -p "$HOME/.docker"
        cp "$source/docker_config.json" "$HOME/.docker/config.json"
        log "INFO" "Restored Docker client config"
    fi
    
    # 3. Restore APT config (requires sudo)
    if [[ -f "$source/apt_proxy.conf" ]] && check_sudo; then
        sudo cp "$source/apt_proxy.conf" /etc/apt/apt.conf.d/95proxies
        log "INFO" "Restored APT proxy config"
    fi
    
    # 4. Restore wget/curl
    [[ -f "$source/wgetrc" ]] && cp "$source/wgetrc" "$HOME/.wgetrc" && log "INFO" "Restored wgetrc"
    [[ -f "$source/curlrc" ]] && cp "$source/curlrc" "$HOME/.curlrc" && log "INFO" "Restored curlrc"
    
    # 5. Restore Cargo config
    if [[ -f "$source/cargo_config.toml" ]]; then
        mkdir -p "$HOME/.cargo"
        cp "$source/cargo_config.toml" "$HOME/.cargo/config.toml"
        log "INFO" "Restored Cargo config"
    fi
    
    # 6. Restore GNOME settings (if available)
    if [[ -f "$source/gnome_proxy.txt" ]] && command_exists gsettings; then
        log "INFO" "GNOME settings restoration requires manual review of $source/gnome_proxy.txt"
    fi
    
    log "SUCCESS" "Snapshot '$name' restored. Some changes may require shell restart."
}

# ----------------------------------------------------------------------------
# Snapshot Listing & Info
# ----------------------------------------------------------------------------

# List all available snapshots
# Usage: list_snapshots
list_snapshots() {
    echo "Available Snapshots:"
    echo ""
    
    if [[ ! -d "$SNAPSHOT_DIR" ]] || [[ -z "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]]; then
        echo "  No snapshots found."
        return 0
    fi
    
    printf "  %-30s %-20s %s\n" "NAME" "CREATED" "SIZE"
    printf "  %-30s %-20s %s\n" "----" "-------" "----"
    
    for snapshot in "$SNAPSHOT_DIR"/*/; do
        [[ ! -d "$snapshot" ]] && continue
        
        local name
        name=$(basename "$snapshot")
        
        local created="unknown"
        if [[ -f "$snapshot/metadata.json" ]] && command_exists jq; then
            created=$(jq -r '.created // "unknown"' "$snapshot/metadata.json" 2>/dev/null | cut -d'T' -f1)
        elif [[ -f "$snapshot/metadata.json" ]]; then
            created=$(grep '"created"' "$snapshot/metadata.json" | cut -d'"' -f4 | cut -d'T' -f1 2>/dev/null)
        fi
        
        local size
        size=$(du -sh "$snapshot" 2>/dev/null | cut -f1)
        
        printf "  %-30s %-20s %s\n" "$name" "$created" "$size"
    done
}

# Show details of a specific snapshot
# Usage: show_snapshot <name>
show_snapshot() {
    local name="$1"
    local source="$SNAPSHOT_DIR/$name"
    
    if [[ ! -d "$source" ]]; then
        log "ERROR" "Snapshot '$name' not found"
        return 1
    fi
    
    echo "Snapshot: $name"
    echo "Location: $source"
    echo ""
    
    if [[ -f "$source/metadata.json" ]]; then
        echo "Metadata:"
        cat "$source/metadata.json"
        echo ""
    fi
    
    echo "Contents:"
    ls -la "$source" | tail -n +2
}

# Compare two snapshots
# Usage: diff_snapshots <name1> <name2>
diff_snapshots() {
    local name1="$1"
    local name2="$2"
    
    if [[ ! -d "$SNAPSHOT_DIR/$name1" ]]; then
        log "ERROR" "Snapshot '$name1' not found"
        return 1
    fi
    
    if [[ ! -d "$SNAPSHOT_DIR/$name2" ]]; then
        log "ERROR" "Snapshot '$name2' not found"
        return 1
    fi
    
    log "INFO" "Comparing snapshots: $name1 vs $name2"
    
    # Compare each common file
    for file in "$SNAPSHOT_DIR/$name1"/*; do
        local filename
        filename=$(basename "$file")
        
        if [[ -f "$SNAPSHOT_DIR/$name2/$filename" ]]; then
            if ! diff -q "$file" "$SNAPSHOT_DIR/$name2/$filename" > /dev/null 2>&1; then
                echo ""
                echo "=== Differences in: $filename ==="
                diff "$file" "$SNAPSHOT_DIR/$name2/$filename" 2>/dev/null || true
            fi
        else
            echo "  [Only in $name1]: $filename"
        fi
    done
    
    for file in "$SNAPSHOT_DIR/$name2"/*; do
        local filename
        filename=$(basename "$file")
        
        if [[ ! -f "$SNAPSHOT_DIR/$name1/$filename" ]]; then
            echo "  [Only in $name2]: $filename"
        fi
    done
}

# Delete a snapshot
# Usage: delete_snapshot <name>
delete_snapshot() {
    local name="$1"
    local target="$SNAPSHOT_DIR/$name"
    
    if [[ ! -d "$target" ]]; then
        log "ERROR" "Snapshot '$name' not found"
        return 1
    fi
    
    rm -rf "$target"
    log "SUCCESS" "Snapshot '$name' deleted"
}

# ----------------------------------------------------------------------------
# Internal Helpers
# ----------------------------------------------------------------------------

# Cleanup old auto-snapshots (keep only MAX_AUTO_SNAPSHOTS)
_cleanup_auto_snapshots() {
    local auto_snapshots
    auto_snapshots=$(ls -d "$SNAPSHOT_DIR"/auto_* 2>/dev/null | sort -r)
    
    local count=0
    for snapshot in $auto_snapshots; do
        ((count++))
        if [[ $count -gt $MAX_AUTO_SNAPSHOTS ]]; then
            rm -rf "$snapshot"
            log "DEBUG" "Cleaned up old auto-snapshot: $(basename "$snapshot")"
        fi
    done
}
