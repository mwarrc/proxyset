#!/bin/bash
# ============================================================================
# ProxySet Module - Gradle
# ============================================================================
# Configures proxy for Gradle build tool.
# Modifies ~/.gradle/gradle.properties.
# ============================================================================

readonly GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"
readonly GRADLE_PROPS="$GRADLE_USER_HOME/gradle.properties"

module_gradle_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    if ! command_exists gradle && [[ ! -d "$GRADLE_USER_HOME" ]]; then
        return 0
    fi
    
    log "INFO" "Configuring Gradle proxy..."
    mkdir -p "$GRADLE_USER_HOME"
    
    local proxy_data
    proxy_data=$(parse_proxy_url "$proxy_url")
    IFS='|' read -r proto user pass host port <<< "$proxy_data"
    
    # Remove old config
    if [[ -f "$GRADLE_PROPS" ]]; then
        sed -i '/systemProp.http.proxy/d' "$GRADLE_PROPS"
        sed -i '/systemProp.https.proxy/d' "$GRADLE_PROPS"
    fi
    
    # Append new config
    {
        echo "systemProp.http.proxyHost=$host"
        echo "systemProp.http.proxyPort=$port"
        echo "systemProp.https.proxyHost=$host"
        echo "systemProp.https.proxyPort=$port"
        
        if [[ -n "$user" ]]; then
            echo "systemProp.http.proxyUser=$user"
            echo "systemProp.http.proxyPassword=$pass"
            echo "systemProp.https.proxyUser=$user"
            echo "systemProp.https.proxyPassword=$pass"
        fi
        
        if [[ -n "$no_proxy" ]]; then
             # Gradle uses pipe | as separator for non-proxy hosts?
             # Actually standard Java uses pipes, but comma often works or pipe.
             # Converting commas to pipes for Java standard compliance
             local non_proxy_java="${no_proxy//,/|}"
             echo "systemProp.http.nonProxyHosts=$non_proxy_java"
             echo "systemProp.https.nonProxyHosts=$non_proxy_java"
        fi
    } >> "$GRADLE_PROPS"
    
    log "SUCCESS" "Gradle proxy configured in $GRADLE_PROPS"
}

module_gradle_unset() {
    if [[ ! -f "$GRADLE_PROPS" ]]; then return 0; fi
    
    log "INFO" "Removing Gradle proxy configuration..."
    sed -i '/systemProp.http.proxy/d' "$GRADLE_PROPS"
    sed -i '/systemProp.https.proxy/d' "$GRADLE_PROPS"
    sed -i '/systemProp.http.nonProxyHosts/d' "$GRADLE_PROPS"
    sed -i '/systemProp.https.nonProxyHosts/d' "$GRADLE_PROPS"
    
    log "SUCCESS" "Gradle proxy removed."
}

module_gradle_status() {
    if [[ ! -f "$GRADLE_PROPS" ]]; then 
        echo "Gradle Proxy: Not configured (File not found)"
        return 0
    fi
    
    echo "Gradle Proxy Configuration:"
    grep "systemProp.*proxyHost" "$GRADLE_PROPS" || echo "  Not configured"
}
