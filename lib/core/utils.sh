#!/bin/bash
# ProxySet Core - Utilities Module

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# safe shell escaping
shell_escape() {
    printf %q "$1"
}

# Run command with sudo if possible, otherwise fail gracefully
run_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command_exists sudo; then
        sudo "$@"
    else
        log "ERROR" "Sudo privileges required for this action."
        return 1
    fi
}

check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    if ! command_exists sudo; then
        return 1
    fi
    if timeout 2 sudo -n true 2>/dev/null; then
        return 0
    fi
    return 1
}

validate_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 ]] && [[ "$1" -le 65535 ]]
}

validate_proxy_type() {
    local type="$1"
    [[ "$type" == "http" || "$type" == "https" || "$type" == "socks4" || "$type" == "socks5" ]]
}

is_wsl() {
    if grep -qE "(Microsoft|WSL)" /proc/version 2>/dev/null; then
        return 0
    fi
    return 1
}

get_wsl_host_ip() {
    if is_wsl; then
        grep nameserver /etc/resolv.conf | awk '{print $2}' | head -n1
    fi
}

# Robust URL Parser
# Extracts: proto, user, pass, host, port
parse_proxy_url() {
    local url="$1"
    
    # regex to parse: [proto://][user[:pass]@]host[:port]
    # This is a basic one, can be improved but is better than cut/sed
    local proto="" user="" pass="" host="" port=""
    
    # Extract proto
    if [[ "$url" =~ ^([a-zA-Z0-9]+):// ]]; then
        proto="${BASH_REMATCH[1]}"
        url="${url#*://}"
    fi
    
    # Extract auth
    if [[ "$url" == *"@"* ]]; then
        local auth="${url%@*}"  # Get everything before the LAST @
        url="${url##*@}"        # Get everything after the LAST @
        if [[ "$auth" == *":"* ]]; then
            user="${auth%%:*}"  # Get everything before the FIRST :
            pass="${auth#*:}"   # Get everything after the FIRST :
        else
            user="$auth"
        fi
    fi
    
    # Extract host and port (IPv6-aware)
    if [[ "$url" == \[*\]* ]]; then
        # Handle [IPv6]:port
        host="${url%%]*}]"   # Extract [::1]
        local remainder="${url#*]}" 
        if [[ "$remainder" == :* ]]; then
            port="${remainder#:}"
            port="${port%%/*}"
        fi
    elif [[ "$url" == *":"* ]]; then
        # Handle IPv4 or Hostname:port
        # We use %%:* which is greedy from the end? No.
        # ${var%%pattern} Remove largest matching suffix pattern.
        # If pattern is :*, and string is host:port
        # Suffix :port matches.
        host="${url%:*}" # Remove shortest match of :* from back (port)
        port="${url##*:}" # Remove longest match of *: from front? No.
        # ${var##pattern} Remove longest matching prefix pattern. 
        # Yes.
        port="${port%%/*}"
    else
        host="${url%%/*}"
    fi

    echo "$proto|$user|$pass|$host|$port"
}

get_xdg_config() {
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/proxyset"
}

get_xdg_cache() {
    echo "${XDG_CACHE_HOME:-$HOME/.cache}/proxyset"
}

get_xdg_data() {
    echo "${XDG_DATA_HOME:-$HOME/.local/share}/proxyset"
}
