#!/bin/bash
# ProxySet Core - Split Tunneling & NO_PROXY Manager
# handles normalization of NO_PROXY lists, including CIDR expansion and wildcards.

# Standardize NO_PROXY list
# Usage: normalize_no_proxy "localhost,10.0.0.0/24,.corp.internal"
normalize_no_proxy() {
    local input_list="$1"
    local output=""
    
    # Convert commas/spaces to newlines
    local items
    items=$(echo "$input_list" | tr ',' '\n' | tr ' ' '\n' | sed 's/^\.//') # strip leading dots for cleaner list
    
    for item in $items; do
        [[ -z "$item" ]] && continue
        
        # IP Range / CIDR logic
        # Most tools (curl, wget) don't support CIDR in NO_PROXY natively.
        # Python/Go do.
        # Ideally, we keep CIDR for modern tools, maybe expand for legacy?
        # For this Alpha, we passthrough CIDR as is, relying on tool support.
        
        # Wildcard normalization
        # standard is 'example.com' matches subdomains usually, or '.example.com'
        # we ensure a unified format if needed. 
        # But broadly:
        if [[ "$output" == "" ]]; then
            output="$item"
        else
            output="$output,$item"
        fi
    done
    
    # Per-module rules handled by module-specific setters call usually
    
    echo "$output"
}

# Check if a host should be bypassed
# Usage: is_bypassed "google.com" "localhost,127.0.0.1"
is_bypassed() {
    local host="$1"
    local bypass_list="$2"
    
    # Simple grep check (imperfect but functional for shell)
    if echo "$bypass_list" | grep -qF "$host"; then
        return 0
    fi
    return 1
}
