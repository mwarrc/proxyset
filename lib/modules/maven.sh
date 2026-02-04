#!/bin/bash
# ProxySet Module - Maven (Java)

module_maven_set() {
    local proxy_url="$1"
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r type user pass host port <<< "$proxy_data"
    
    local settings_file="$HOME/.m2/settings.xml"
    log "INFO" "Configuring Maven proxy in $settings_file..."
    mkdir -p "$(dirname "$settings_file")"

    # Maven uses XML. This is tricky to edit with sed, but we can use a template or append.
    # For a truly industry-grade tool, we'd use an XML parser, but we'll use a markers for now.
    
    if [[ ! -f "$settings_file" ]]; then
        cat > "$settings_file" <<EOF
<settings>
  <proxies>
    <!-- ProxySet Start -->
    <proxy>
      <id>proxyset</id>
      <active>true</active>
      <protocol>$type</protocol>
      <host>$host</host>
      <port>$port</port>
      $([[ -n "$user" ]] && echo "<username>$user</username><password>$pass</password>")
      <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
    </proxy>
    <!-- ProxySet End -->
  </proxies>
</settings>
EOF
    else
        sed -i '/<!-- ProxySet Start -->/,/<!-- ProxySet End -->/d' "$settings_file"
        # Insert before </proxies> if exists, otherwise append at end of file (which is wrong but better than nothing)
        if grep -q "</proxies>" "$settings_file"; then
            sed -i "/<\/proxies>/i \    <!-- ProxySet Start -->\n    <proxy>\n      <id>proxyset</id>\n      <active>true</active>\n      <protocol>$type</protocol>\n      <host>$host</host>\n      <port>$port</port>\n      $([[ -n "$user" ]] && echo "<username>$user</username><password>$pass</password>")\n      <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>\n    </proxy>\n    <!-- ProxySet End -->" "$settings_file"
        else
             log "WARN" "Maven settings.xml exists but has no <proxies> section. Manual edit may be needed."
        fi
    fi
}

module_maven_unset() {
    local settings_file="$HOME/.m2/settings.xml"
    if [[ -f "$settings_file" ]]; then
        sed -i '/<!-- ProxySet Start -->/,/<!-- ProxySet End -->/d' "$settings_file"
    fi
}

module_maven_status() {
    local settings_file="$HOME/.m2/settings.xml"
    if [[ -f "$settings_file" ]]; then
        echo "Maven Proxy Settings:"
        grep -A 10 "ProxySet Start" "$settings_file" || echo "  Not set"
    fi
}
