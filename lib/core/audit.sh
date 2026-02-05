#!/bin/bash
# ProxySet Core - Security Audit Module
# Manages audit logging with integrity verification (SHA256/GPG) and rotation.

AUDIT_LOG="${DATA_DIR:-$HOME/.local/share/proxyset}/audit.json"
MAX_AUDIT_SIZE=$((10 * 1024 * 1024)) # 10MB

# Rotate log if it exceeds max size
rotate_audit_log() {
    if [[ -f "$AUDIT_LOG" ]]; then
        local size
        size=$(stat -c%s "$AUDIT_LOG" 2>/dev/null || stat -f%z "$AUDIT_LOG" 2>/dev/null)
        
        if [[ -n "$size" && "$size" -gt "$MAX_AUDIT_SIZE" ]]; then
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            local archive="$AUDIT_LOG.$timestamp.gz"
            log "INFO" "Rotating audit log to $archive"
            gzip -c "$AUDIT_LOG" > "$archive"
            > "$AUDIT_LOG" # Truncate old log
        fi
    fi
}

log_audit() {
    local action="$1"
    local target="$2"
    local details="$3"
    
    rotate_audit_log
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ") # UTC ISO-8601
    local user
    user=$(whoami)
    
    mkdir -p "$(dirname "$AUDIT_LOG")"
    
    # Construct core payload
    # Note: We manually construct JSON and must escape double quotes in user-provided fields.
    local e_action="${action//\"/\\\"}"
    local e_target="${target//\"/\\\"}"
    local e_details="${details//\"/\\\"}"
    
    local payload="\"timestamp\": \"$timestamp\", \"user\": \"$user\", \"action\": \"$e_action\", \"target\": \"$e_target\", \"details\": \"$e_details\""
    
    # 1.15 Calculate SHA256 Checksum of the payload
    # We use basic tools (sha256sum or shasum)
    local checksum="null"
    if command_exists sha256sum; then
        checksum=$(echo -n "{$payload}" | sha256sum | awk '{print $1}')
    elif command_exists shasum; then
        checksum=$(echo -n "{$payload}" | shasum -a 256 | awk '{print $1}')
    fi
    
    # 1.16 Optional GPG Signing
    local signature="null"
    if [[ -n "$PROXYSET_GPG_KEY" ]] && command_exists gpg; then
        # Detached ascii armoed signature of the payload
        signature=$(echo -n "{$payload}" | gpg --detach-sign --armor --default-key "$PROXYSET_GPG_KEY" 2>/dev/null | tr -d '\n')
    fi

    # Final Audit Entry
    local entry="{$payload, \"checksum\": \"$checksum\", \"signature\": \"$signature\"}"
    echo "$entry" >> "$AUDIT_LOG"
}

view_audit() {
    if [[ -f "$AUDIT_LOG" ]]; then
        echo "ProxySet Audit History:"
        if command_exists jq; then
            cat "$AUDIT_LOG" | jq .
        else
            cat "$AUDIT_LOG"
        fi
    else
        echo "No audit logs found."
    fi
}

# Verify audit log integrity
verify_audit() {
    local failures=0
    local line_num=0
    
    if [[ ! -f "$AUDIT_LOG" ]]; then
        log "WARN" "No audit log to verify."
        return 0
    fi
    
    log "INFO" "Verifying audit log integrity..."
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        ((line_num++))
        
        # Extract checksum (last field before signature or at end)
        local stored_checksum
        stored_checksum=$(echo "$line" | sed -E 's/.*"checksum": "([^"]*)".*/\1/')
        
        # Reconstruct payload to verify
        # Everything before the checksum field
        local payload_raw
        payload_raw=$(echo "$line" | sed -E 's/, "checksum":.*//')
        if [[ "$payload_raw" != *"}" ]]; then payload_raw="${payload_raw}}"; fi
        
        # Recalculate
        local calc_checksum="null"
        if command_exists sha256sum; then
            calc_checksum=$(echo -n "$payload_raw" | sha256sum | awk '{print $1}')
        elif command_exists shasum; then
            calc_checksum=$(echo -n "$payload_raw" | shasum -a 256 | awk '{print $1}')
        fi
        
        if [[ "$stored_checksum" != "null" && "$stored_checksum" != "$calc_checksum" ]]; then
            log "ERROR" "Integrity failure at line $line_num (Stored: ${stored_checksum:0:8}, Calc: ${calc_checksum:0:8})"
            ((failures++))
        fi
    done < "$AUDIT_LOG"
    
    if [[ "$failures" -eq 0 ]]; then
        log "SUCCESS" "Audit log verified ($line_num entries)."
    else
        log "ERROR" "Audit log verification failed with $failures errors."
        return 1
    fi
}
