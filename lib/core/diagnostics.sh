#!/bin/bash
# ProxySet Core - Diagnostics Module

run_diagnostics() {
    log "INFO" "Initializing Network Security Audit..."
    echo ""
    
    echo -e "${BOLD}${WHITE}┃ SYSTEM ARCHITECTURE${NC}"
    echo -e "${DIM}┠─${NC} Hostname : $(hostname)"
    echo -e "${DIM}┠─${NC} Platform : $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
    echo -e "${DIM}┗─${NC} Kernel   : $(uname -r)"
    echo ""
    
    echo -e "${BOLD}${WHITE}┃ NETWORK INTERFACES${NC}"
    if command_exists ip; then
        ip -br addr show | sed 's/^/  /'
    else
        ifconfig -a | grep -E "flags|inet" | sed 's/^/  /'
    fi
    echo ""
    
    echo -e "${BOLD}${WHITE}┃ ROUTING TOPOLOGY${NC}"
    if command_exists ip; then
        ip route show | sed 's/^/  /'
    else
        route -n | sed 's/^/  /'
    fi
    echo ""
    
    echo -e "${BOLD}${WHITE}┃ PROXY INTEGRITY CHECK${NC}"
    # Check current env vars
    echo "HTTP_PROXY: ${http_proxy:-Not set}"
    echo "HTTPS_PROXY: ${https_proxy:-Not set}"
    
    if [[ -n "${http_proxy:-}" ]]; then
        log "PROGRESS" "Measuring latency to proxy infrastructure..."
        local proxy_data proxy_host
        proxy_data=$(parse_proxy_url "$http_proxy")
        proxy_host=$(echo "$proxy_data" | cut -d'|' -f4)
        
        if ping -c 3 -W 2 "$proxy_host" > /dev/null 2>&1; then
            local rtt
            rtt=$(ping -c 3 "$proxy_host" | tail -1 | awk -F '/' '{print $5}')
            log "SUCCESS" "Baseline Latency: ${rtt}ms (avg)"
        else
            log "WARN" "Proxy infrastructure unreachable via ICMP (No Ping)."
        fi
        
        echo ""
        log "PROGRESS" "Conducting IP Leak Analysis..."
        local actual_ip
        actual_ip=$(curl -s --max-time 5 -x "$http_proxy" http://ifconfig.me || echo "FAILED")
        local real_ip
        real_ip=$(curl -s --max-time 5 http://ifconfig.me || echo "FAILED")
        
        echo -e "  ${BOLD}Virtual IP  :${NC} ${CYAN}$actual_ip${NC}"
        echo -e "  ${BOLD}Local IP    :${NC} ${DIM}$real_ip${NC}"
        echo ""
        
        if [[ "$actual_ip" == "$real_ip" && "$actual_ip" != "FAILED" ]]; then
            log "ERROR" "CRITICAL: NETWORK TRANSIT IS UNSECURED (LEAK DETECTED)"
            alert_health_failure "IP Leak Detected"
        elif [[ "$actual_ip" == "FAILED" ]]; then
             log "WARN" "Proxy validation failed: Infrastructure may be offline."
        else
            log "SUCCESS" "Network identity successfully masked."
        fi
        
        # IPv6 Dual-Stack Test
        echo ""
        log "PROGRESS" "Testing IPv6 Connectivity..."
        if ping6 -c 1 -W 2 google.com >/dev/null 2>&1; then
             local ipv6_addr
             ipv6_addr=$(curl -6 -s --max-time 5 -x "$http_proxy" http://ifconfig.me || echo "FAILED")
             if [[ "$ipv6_addr" != "FAILED" ]]; then
                 echo -e "  ${BOLD}IPv6 Address:${NC} ${CYAN}$ipv6_addr${NC}"
             else
                 log "WARN" "IPv6 connectivity detected but proxying failed."
             fi
        else
             echo -e "  ${DIM}IPv6 connectivity unavailable on this host.${NC}"
        fi
    fi
}

alert_health_failure() {
    local reason="$1"
    echo -e "\a"
    log "ERROR" "HEALTH CHECK FAILED: $reason"
}

check_health() {
    local proxy="${http_proxy:-}"
    if [[ -z "$proxy" ]]; then return 1; fi
    
    if curl -s --max-time 3 -x "$proxy" http://captive.apple.com/hotspot-detect.html | grep -q "Success"; then
        return 0
    else
        return 1
    fi
}
