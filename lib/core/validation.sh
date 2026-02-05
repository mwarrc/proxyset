#!/bin/bash
# ============================================================================
# ProxySet Core - Input Validation Module
# ============================================================================
# Provides comprehensive input validation and sanitization functions.
# All functions return 0 on success, 1 on failure.
# ============================================================================

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

# Allowed proxy protocols (whitelist approach for security)
readonly VALID_PROXY_TYPES=("http" "https" "socks4" "socks5" "socks5h")

# Maximum lengths to prevent buffer/memory issues
readonly MAX_HOSTNAME_LENGTH=253
readonly MAX_USERNAME_LENGTH=256
readonly MAX_PASSWORD_LENGTH=256
readonly MAX_URL_LENGTH=2048

# ----------------------------------------------------------------------------
# Hostname & IP Validation
# ----------------------------------------------------------------------------

# Validate IPv4 address format
# Usage: validate_ipv4 "192.168.1.1"
# Returns: 0 if valid, 1 if invalid
validate_ipv4() {
    local ip="$1"
    local IFS='.'
    local -a octets
    
    [[ -z "$ip" ]] && return 1
    
    read -ra octets <<< "$ip"
    [[ ${#octets[@]} -ne 4 ]] && return 1
    
    for octet in "${octets[@]}"; do
        # Must be numeric
        [[ ! "$octet" =~ ^[0-9]+$ ]] && return 1
        # Must be 0-255
        [[ "$octet" -lt 0 || "$octet" -gt 255 ]] && return 1
        # No leading zeros (except for 0 itself)
        [[ "$octet" != "0" && "$octet" =~ ^0 ]] && return 1
    done
    
    return 0
}

# Validate IPv6 address format (simplified check)
# Usage: validate_ipv6 "::1" or "2001:db8::1"
# Returns: 0 if valid, 1 if invalid
validate_ipv6() {
    local ip="$1"
    
    [[ -z "$ip" ]] && return 1
    
    # Strip brackets if present
    if [[ "$ip" == \[*\] ]]; then
        ip="${ip:1:${#ip}-2}"
    fi

    # Basic IPv6 regex pattern
    # Matches: ::1, ::, 2001:db8::1, fe80::1%eth0, etc.
    # We use a loose check for colons and hex, because strict IPv6 regex is massive.
    if [[ "$ip" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}(%[a-zA-Z0-9]+)?$ ]]; then return 0; fi
    if [[ "$ip" =~ ^::$ ]]; then return 0; fi
    if [[ "$ip" =~ ^::1$ ]]; then return 0; fi
    
    return 1
}

# Validate hostname format (RFC 1123)
# Usage: validate_hostname "proxy.example.com"
# Returns: 0 if valid, 1 if invalid
validate_hostname() {
    local hostname="$1"
    
    [[ -z "$hostname" ]] && return 1
    [[ ${#hostname} -gt $MAX_HOSTNAME_LENGTH ]] && return 1
    
    # Hostname pattern: alphanumeric, hyphens, dots
    # Each label: 1-63 chars, start/end with alphanumeric
    local hostname_pattern='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
    
    [[ "$hostname" =~ $hostname_pattern ]] && return 0
    return 1
}

# Validate host (can be IPv4, IPv6, or hostname)
# Usage: validate_host "proxy.example.com"
# Returns: 0 if valid, 1 if invalid
validate_host() {
    local host="$1"
    
    [[ -z "$host" ]] && return 1
    
    # Try each validation in order
    validate_ipv4 "$host" && return 0
    validate_ipv6 "$host" && return 0
    validate_hostname "$host" && return 0
    
    return 1
}

# ----------------------------------------------------------------------------
# Port Validation
# ----------------------------------------------------------------------------

# Validate port number (1-65535)
# Usage: validate_port "8080"
# Returns: 0 if valid, 1 if invalid
validate_port() {
    local port="$1"
    
    [[ -z "$port" ]] && return 1
    [[ ! "$port" =~ ^[0-9]+$ ]] && return 1
    [[ "$port" -lt 1 || "$port" -gt 65535 ]] && return 1
    
    return 0
}

# ----------------------------------------------------------------------------
# Proxy Type Validation
# ----------------------------------------------------------------------------

# Validate proxy type against whitelist
# Usage: validate_proxy_type "socks5"
# Returns: 0 if valid, 1 if invalid
validate_proxy_type() {
    local type="$1"
    
    [[ -z "$type" ]] && return 1
    
    for valid_type in "${VALID_PROXY_TYPES[@]}"; do
        [[ "$type" == "$valid_type" ]] && return 0
    done
    
    return 1
}

# ----------------------------------------------------------------------------
# Credential Validation
# ----------------------------------------------------------------------------

# Validate username format (no shell-dangerous characters)
# Usage: validate_username "myuser"
# Returns: 0 if valid, 1 if invalid
validate_username() {
    local username="$1"
    
    [[ -z "$username" ]] && return 0  # Empty is valid (optional)
    [[ ${#username} -gt $MAX_USERNAME_LENGTH ]] && return 1
    
    # Allow alphanumeric, underscore, hyphen, dot, @
    # Reject shell metacharacters: $ ` \ " ' ; | & < > ( ) { } [ ] ! # 
    local username_pattern='^[a-zA-Z0-9_.@-]+$'
    
    [[ "$username" =~ $username_pattern ]] && return 0
    return 1
}

# Validate password doesn't contain null bytes or newlines
# (Other special chars are allowed but will be URL-encoded)
# Usage: validate_password "mypass"
# Returns: 0 if valid, 1 if invalid
validate_password() {
    local password="$1"
    
    [[ -z "$password" ]] && return 0  # Empty is valid (optional)
    [[ ${#password} -gt $MAX_PASSWORD_LENGTH ]] && return 1
    
    # Reject null bytes and newlines
    [[ "$password" == *$'\0'* ]] && return 1
    [[ "$password" == *$'\n'* ]] && return 1
    
    return 0
}

# ----------------------------------------------------------------------------
# URL Validation
# ----------------------------------------------------------------------------

# Validate complete proxy URL
# Usage: validate_proxy_url "http://user:pass@proxy.com:8080"
# Returns: 0 if valid, 1 if invalid
validate_proxy_url() {
    local url="$1"
    
    [[ -z "$url" ]] && return 1
    [[ ${#url} -gt $MAX_URL_LENGTH ]] && return 1
    
    # Parse the URL
    local parsed
    parsed=$(parse_proxy_url "$url")
    
    IFS='|' read -r proto user pass host port <<< "$parsed"
    
    # Validate each component
    [[ -n "$proto" ]] && ! validate_proxy_type "$proto" && return 1
    [[ -n "$user" ]] && ! validate_username "$user" && return 1
    [[ -n "$pass" ]] && ! validate_password "$pass" && return 1
    ! validate_host "$host" && return 1
    [[ -n "$port" ]] && ! validate_port "$port" && return 1
    
    return 0
}

# ----------------------------------------------------------------------------
# Sanitization Functions
# ----------------------------------------------------------------------------

# URL-encode special characters in a string
# Usage: url_encode "user@name"
# Output: Encoded string to stdout
url_encode() {
    local string="$1"
    local length=${#string}
    local encoded=""
    local c
    
    for ((i = 0; i < length; i++)); do
        c="${string:i:1}"
        case "$c" in
            [a-zA-Z0-9.~_-]) encoded+="$c" ;;
            *) encoded+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    
    echo "$encoded"
}

# Escape string for safe use in shell commands
# Usage: shell_escape "some; dangerous && string"
# Output: Safely quoted string to stdout
shell_escape() {
    printf '%q' "$1"
}

# Sanitize string for log output (redact sensitive patterns)
# Usage: sanitize_for_log "http://user:password@host:port"
# Output: Redacted string to stdout
sanitize_for_log() {
    local input="$1"
    
    # Redact password in URLs (user:PASSWORD@host)
    local output
    output=$(echo "$input" | sed -E 's/(:\/\/[^:]+:)[^@]+(@)/\1***REDACTED***\2/g')
    
    # Redact common sensitive keywords
    output=$(echo "$output" | sed -E 's/(password|passwd|pass|secret|token|api_key|apikey)[[:space:]]*[=:][[:space:]]*[^[:space:]]*/\1=***REDACTED***/gi')
    
    echo "$output"
}

# ----------------------------------------------------------------------------
# Composite Validation with Error Messages
# ----------------------------------------------------------------------------

# Validate all proxy parameters
# Usage: validate_proxy_params host port [type] [user] [pass]
# Returns: 0 if valid, 1 if invalid (prints error to stderr)
validate_proxy_params() {
    local host="$1"
    local port="$2"
    local type="${3:-http}"
    local user="${4:-}"
    local pass="${5:-}"
    
    if [[ -z "$host" ]]; then
        echo "Validation Error: Host is required" >&2
        return 1
    fi
    
    if ! validate_host "$host"; then
        echo "Validation Error: Invalid host format: $host" >&2
        return 1
    fi
    
    if [[ -z "$port" ]]; then
        echo "Validation Error: Port is required" >&2
        return 1
    fi
    
    if ! validate_port "$port"; then
        echo "Validation Error: Invalid port: $port (must be 1-65535)" >&2
        return 1
    fi
    
    if ! validate_proxy_type "$type"; then
        echo "Validation Error: Invalid proxy type: $type (allowed: ${VALID_PROXY_TYPES[*]})" >&2
        return 1
    fi
    
    if [[ -n "$user" ]] && ! validate_username "$user"; then
        echo "Validation Error: Invalid username format (only alphanumeric, _, -, ., @ allowed)" >&2
        return 1
    fi
    
    if [[ -n "$pass" ]] && ! validate_password "$pass"; then
        echo "Validation Error: Invalid password (contains forbidden characters)" >&2
        return 1
    fi
    
    return 0
}

# Build a validated proxy URL from components
# Usage: build_proxy_url host port [type] [user] [pass]
# Output: Validated proxy URL to stdout, or empty on error
build_proxy_url() {
    local host="$1"
    local port="$2"
    local type="${3:-http}"
    local user="${4:-}"
    local pass="${5:-}"
    
    # Validate first
    if ! validate_proxy_params "$host" "$port" "$type" "$user" "$pass"; then
        return 1
    fi
    
    # Build URL with proper encoding
    local url="${type}://"
    
    if [[ -n "$user" ]]; then
        url+="$(url_encode "$user")"
        if [[ -n "$pass" ]]; then
            url+=":$(url_encode "$pass")"
        fi
        url+="@"
    fi
    
    url+="${host}:${port}"
    
    echo "$url"
}
