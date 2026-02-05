PROFILE_DIR="${CONFIG_DIR:-$HOME/.config/proxyset}/profiles"

init_profiles() {
    mkdir -p "$PROFILE_DIR"
}

save_profile() {
    local name="$1"
    local proxy_url="$2"
    local no_proxy="$3"
    local encrypt="${4:-false}"
    
    if [[ -z "$name" ]]; then die "Profile name required."; fi
    
    local content
    content="proxy_url=\"$proxy_url\"
no_proxy=\"$no_proxy\""

    if [[ "$encrypt" == "true" ]]; then
        if command_exists gpg; then
            echo "$content" | gpg --symmetric --batch --yes --passphrase-file <(echo "${PROXYSET_PASSPHRASE:-proxyset}") --output "$PROFILE_DIR/$name.conf.gpg"
            log "SUCCESS" "Profile '$name' saved and encrypted."
            rm -f "$PROFILE_DIR/$name.conf" 2>/dev/null
        else
            log "WARN" "GPG not found. Saving as plain text."
            echo "$content" > "$PROFILE_DIR/$name.conf"
        fi
    else
        echo "$content" > "$PROFILE_DIR/$name.conf"
        log "SUCCESS" "Profile '$name' saved."
    fi
}

load_profile() {
    local name="$1"
    local file=""
    
    if [[ -f "$PROFILE_DIR/$name.conf.gpg" ]]; then
        if command_exists gpg; then
            file=$(mktemp)
            gpg --decrypt --batch --passphrase-file <(echo "${PROXYSET_PASSPHRASE:-proxyset}") --output "$file" "$PROFILE_DIR/$name.conf.gpg" 2>/dev/null
        else
            die "GPG required to load encrypted profile '$name'."
        fi
    elif [[ -f "$PROFILE_DIR/$name.conf" ]]; then
        file="$PROFILE_DIR/$name.conf"
    fi

    if [[ -n "$file" && -f "$file" ]]; then
        # Use safe_source to validate ownership/permissions before sourcing
        if safe_source "$file"; then
            run_module_cmd "set" "$proxy_url" "$no_proxy"
            log "SUCCESS" "Profile '$name' loaded and applied."
        else
            die "Failed to load or validate profile file: $name"
        fi
        
        # Cleanup temp file if it was decrypted
        [[ "$file" == /tmp/* ]] && rm -f "$file"
    else
        log "ERROR" "Profile '$name' not found."
    fi
}

list_profiles() {
    echo "Saved Profiles:"
    ls "$PROFILE_DIR" 2>/dev/null | sed -e 's/\.conf$//' -e 's/\.conf\.gpg$//' | sort -u | sed 's/^/  - /'
}
