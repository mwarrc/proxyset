#!/bin/bash
# ProxySet Module - Firefox (Policy-based)

module_firefox_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    local host
    local port
    host=$(echo "$proxy_url" | sed -e 's|.*://||' -e 's|:.*||' -e 's|/.*||')
    port=$(echo "$proxy_url" | sed -e 's|.*:||' -e 's|/.*||')

    log "INFO" "Configuring Firefox system-wide policy proxy..."
    
    # Firefox looks for policies.json in /usr/lib/firefox/distribution/ or /etc/firefox/policies/
    local policy_dir="/etc/firefox/policies"
    if check_sudo; then
        sudo mkdir -p "$policy_dir"
        cat <<EOF | sudo tee "$policy_dir/policies.json" > /dev/null
{
  "policies": {
    "Proxy": {
      "Mode": "manual",
      "HTTPProxy": "$host:$port",
      "UseHTTPProxyForAllProtocols": true,
      "NoProxy": "$no_proxy"
    }
  }
}
EOF
    else
        log "WARN" "Sudo required to set Firefox system policy."
    fi
}

module_firefox_unset() {
    local policy_file="/etc/firefox/policies/policies.json"
    if [[ -f "$policy_file" ]] && check_sudo; then
        log "INFO" "Removing Firefox system policy..."
        sudo rm "$policy_file"
    fi
}

module_firefox_status() {
    local policy_file="/etc/firefox/policies/policies.json"
    if [[ -f "$policy_file" ]]; then
        echo "Firefox Policy Proxy:"
        cat "$policy_file"
    else
        echo "Firefox Policy: Not set"
    fi
}
