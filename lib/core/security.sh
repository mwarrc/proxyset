#!/bin/bash
# ============================================================================
# ProxySet Core - Security & Credential Management Module
# ============================================================================
# Provides secure credential storage and retrieval using system keyrings.
# Supports: GNOME Keyring, KDE Wallet, pass (password-store), GPG fallback.
# ============================================================================

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

readonly PROXYSET_KEYRING_SERVICE="proxyset"
readonly PROXYSET_KEYRING_ATTR="proxy-profile"

# ----------------------------------------------------------------------------
# Keyring Backend Detection
# ----------------------------------------------------------------------------

# Detect the best available credential storage backend
# Usage: detect_keyring_backend
# Output: Backend name to stdout (gnome|kde|pass|gpg|none)
detect_keyring_backend() {
    # Check for GNOME Keyring (secret-tool)
    if command_exists secret-tool; then
        # Verify the service is actually running
        if secret-tool lookup test-connectivity proxyset 2>/dev/null || true; then
            echo "gnome"
            return 0
        fi
    fi
    
    # Check for KDE Wallet
    if command_exists kwallet-query && [[ -n "${KDE_SESSION_VERSION:-}" ]]; then
        echo "kde"
        return 0
    fi
    
    # Check for pass (password-store)
    if command_exists pass; then
        if [[ -d "${PASSWORD_STORE_DIR:-$HOME/.password-store}" ]]; then
            echo "pass"
            return 0
        fi
    fi
    
    # Fallback to GPG
    if command_exists gpg; then
        echo "gpg"
        return 0
    fi
    
    echo "none"
    return 1
}

# ----------------------------------------------------------------------------
# Secure Password Prompt
# ----------------------------------------------------------------------------

# Prompt for password securely (no echo, cleared from memory)
# Usage: secure_password_prompt "Enter password: "
# Output: Password to stdout
secure_password_prompt() {
    local prompt="${1:-Password: }"
    local password=""
    
    # Disable echo
    stty -echo 2>/dev/null || true
    
    # Read password
    read -rp "$prompt" password
    
    # Re-enable echo
    stty echo 2>/dev/null || true
    
    # Print newline (since Enter wasn't echoed)
    echo >&2
    
    # Output password
    echo "$password"
}

# ----------------------------------------------------------------------------
# GNOME Keyring Backend
# ----------------------------------------------------------------------------

# Store credential in GNOME Keyring
# Usage: keyring_gnome_store "profile-name" "password"
# Returns: 0 on success, 1 on failure
keyring_gnome_store() {
    local profile="$1"
    local secret="$2"
    
    if ! command_exists secret-tool; then
        return 1
    fi
    
    echo -n "$secret" | secret-tool store --label="ProxySet: $profile" \
        service "$PROXYSET_KEYRING_SERVICE" \
        "$PROXYSET_KEYRING_ATTR" "$profile" 2>/dev/null
}

# Retrieve credential from GNOME Keyring
# Usage: keyring_gnome_retrieve "profile-name"
# Output: Secret to stdout
keyring_gnome_retrieve() {
    local profile="$1"
    
    if ! command_exists secret-tool; then
        return 1
    fi
    
    secret-tool lookup \
        service "$PROXYSET_KEYRING_SERVICE" \
        "$PROXYSET_KEYRING_ATTR" "$profile" 2>/dev/null
}

# Delete credential from GNOME Keyring
# Usage: keyring_gnome_delete "profile-name"
# Returns: 0 on success
keyring_gnome_delete() {
    local profile="$1"
    
    if ! command_exists secret-tool; then
        return 1
    fi
    
    secret-tool clear \
        service "$PROXYSET_KEYRING_SERVICE" \
        "$PROXYSET_KEYRING_ATTR" "$profile" 2>/dev/null
}

# ----------------------------------------------------------------------------
# KDE Wallet Backend
# ----------------------------------------------------------------------------

# Store credential in KDE Wallet
# Usage: keyring_kde_store "profile-name" "password"
# Returns: 0 on success, 1 on failure
keyring_kde_store() {
    local profile="$1"
    local secret="$2"
    local wallet="${KDE_WALLET:-kdewallet}"
    
    if ! command_exists kwallet-query; then
        return 1
    fi
    
    echo -n "$secret" | kwallet-query -w "$wallet" -f "$PROXYSET_KEYRING_SERVICE" \
        --write-password "$profile" 2>/dev/null
}

# Retrieve credential from KDE Wallet
# Usage: keyring_kde_retrieve "profile-name"
# Output: Secret to stdout
keyring_kde_retrieve() {
    local profile="$1"
    local wallet="${KDE_WALLET:-kdewallet}"
    
    if ! command_exists kwallet-query; then
        return 1
    fi
    
    kwallet-query -w "$wallet" -f "$PROXYSET_KEYRING_SERVICE" \
        --read-password "$profile" 2>/dev/null
}

# Delete credential from KDE Wallet
# Usage: keyring_kde_delete "profile-name"
# Returns: 0 on success
keyring_kde_delete() {
    local profile="$1"
    local wallet="${KDE_WALLET:-kdewallet}"
    
    if ! command_exists kwallet-query; then
        return 1
    fi
    
    kwallet-query -w "$wallet" -f "$PROXYSET_KEYRING_SERVICE" \
        --delete-password "$profile" 2>/dev/null
}

# ----------------------------------------------------------------------------
# Pass (password-store) Backend
# ----------------------------------------------------------------------------

# Store credential in pass
# Usage: keyring_pass_store "profile-name" "password"
# Returns: 0 on success, 1 on failure
keyring_pass_store() {
    local profile="$1"
    local secret="$2"
    
    if ! command_exists pass; then
        return 1
    fi
    
    echo -n "$secret" | pass insert -m "proxyset/$profile" 2>/dev/null
}

# Retrieve credential from pass
# Usage: keyring_pass_retrieve "profile-name"
# Output: Secret to stdout
keyring_pass_retrieve() {
    local profile="$1"
    
    if ! command_exists pass; then
        return 1
    fi
    
    pass show "proxyset/$profile" 2>/dev/null | head -n1
}

# Delete credential from pass
# Usage: keyring_pass_delete "profile-name"
# Returns: 0 on success
keyring_pass_delete() {
    local profile="$1"
    
    if ! command_exists pass; then
        return 1
    fi
    
    pass rm -f "proxyset/$profile" 2>/dev/null
}

# ----------------------------------------------------------------------------
# GPG Fallback Backend
# ----------------------------------------------------------------------------

# Get GPG credential file path
# Usage: _gpg_cred_file "profile-name"
_gpg_cred_file() {
    local profile="$1"
    echo "${CONFIG_DIR:-$HOME/.config/proxyset}/credentials/${profile}.gpg"
}

# Store credential using GPG encryption
# Usage: keyring_gpg_store "profile-name" "password" [passphrase]
# Returns: 0 on success, 1 on failure
keyring_gpg_store() {
    local profile="$1"
    local secret="$2"
    local passphrase="${3:-${PROXYSET_PASSPHRASE:-}}"
    local cred_file
    
    cred_file=$(_gpg_cred_file "$profile")
    
    if ! command_exists gpg; then
        return 1
    fi
    
    mkdir -p "$(dirname "$cred_file")"
    chmod 700 "$(dirname "$cred_file")"
    
    if [[ -n "$passphrase" ]]; then
        echo -n "$secret" | gpg --symmetric --batch --yes \
            --passphrase-fd 3 3<<<"$passphrase" \
            --output "$cred_file" 2>/dev/null
    else
        # Interactive passphrase
        echo -n "$secret" | gpg --symmetric --batch --yes \
            --output "$cred_file" 2>/dev/null
    fi
    
    chmod 600 "$cred_file"
}

# Retrieve credential using GPG decryption
# Usage: keyring_gpg_retrieve "profile-name" [passphrase]
# Output: Secret to stdout
keyring_gpg_retrieve() {
    local profile="$1"
    local passphrase="${2:-${PROXYSET_PASSPHRASE:-}}"
    local cred_file
    
    cred_file=$(_gpg_cred_file "$profile")
    
    if ! command_exists gpg || [[ ! -f "$cred_file" ]]; then
        return 1
    fi
    
    if [[ -n "$passphrase" ]]; then
        gpg --decrypt --batch --quiet \
            --passphrase-fd 3 3<<<"$passphrase" \
            "$cred_file" 2>/dev/null
    else
        gpg --decrypt --batch --quiet "$cred_file" 2>/dev/null
    fi
}

# Delete GPG credential file
# Usage: keyring_gpg_delete "profile-name"
# Returns: 0 on success
keyring_gpg_delete() {
    local profile="$1"
    local cred_file
    
    cred_file=$(_gpg_cred_file "$profile")
    
    if [[ -f "$cred_file" ]]; then
        # Secure delete if shred is available
        if command_exists shred; then
            shred -u "$cred_file" 2>/dev/null
        else
            rm -f "$cred_file"
        fi
    fi
}

# ----------------------------------------------------------------------------
# Unified Keyring Interface
# ----------------------------------------------------------------------------

# Store credential using best available backend
# Usage: credential_store "profile-name" "secret"
# Returns: 0 on success, 1 on failure
credential_store() {
    local profile="$1"
    local secret="$2"
    local backend
    
    backend=$(detect_keyring_backend)
    
    case "$backend" in
        gnome) keyring_gnome_store "$profile" "$secret" ;;
        kde)   keyring_kde_store "$profile" "$secret" ;;
        pass)  keyring_pass_store "$profile" "$secret" ;;
        gpg)   keyring_gpg_store "$profile" "$secret" ;;
        *)
            log "WARN" "No secure credential storage available. Credentials will not be saved."
            return 1
            ;;
    esac
}

# Retrieve credential using best available backend
# Usage: credential_retrieve "profile-name"
# Output: Secret to stdout
credential_retrieve() {
    local profile="$1"
    local backend
    
    backend=$(detect_keyring_backend)
    
    case "$backend" in
        gnome) keyring_gnome_retrieve "$profile" ;;
        kde)   keyring_kde_retrieve "$profile" ;;
        pass)  keyring_pass_retrieve "$profile" ;;
        gpg)   keyring_gpg_retrieve "$profile" ;;
        *)     return 1 ;;
    esac
}

# Delete credential using best available backend
# Usage: credential_delete "profile-name"
# Returns: 0 on success
credential_delete() {
    local profile="$1"
    local backend
    
    backend=$(detect_keyring_backend)
    
    case "$backend" in
        gnome) keyring_gnome_delete "$profile" ;;
        kde)   keyring_kde_delete "$profile" ;;
        pass)  keyring_pass_delete "$profile" ;;
        gpg)   keyring_gpg_delete "$profile" ;;
        *)     return 1 ;;
    esac
}

# Check if credential exists
# Usage: credential_exists "profile-name"
# Returns: 0 if exists, 1 if not
credential_exists() {
    local profile="$1"
    local secret
    
    secret=$(credential_retrieve "$profile" 2>/dev/null)
    [[ -n "$secret" ]]
}

# ----------------------------------------------------------------------------
# Security Utilities
# ----------------------------------------------------------------------------

# Clear sensitive variables from memory
# Usage: secure_clear VAR1 VAR2 ...
secure_clear() {
    for var in "$@"; do
        unset "$var"
    done
}

# Generate a random token (for temporary credentials)
# Usage: generate_token [length]
# Output: Random hex string to stdout
generate_token() {
    local length="${1:-32}"
    
    if [[ -r /dev/urandom ]]; then
        head -c "$length" /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c "$length"
    elif command_exists openssl; then
        openssl rand -hex "$((length / 2))"
    else
        # Fallback (less secure)
        date +%s%N | sha256sum | head -c "$length"
    fi
}
