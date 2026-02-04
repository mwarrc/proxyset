#!/bin/bash
# ProxySet Core - Interactive Wizard Module

run_wizard() {
    clear
    show_banner
    echo -e "${BOLD}${WHITE}  INTERACTIVE SETUP UTILITY${NC}"
    echo -e "${DIM}  ───────────────────────────────${NC}"
    echo ""

    # 1. Server Host
    read -rp "Enter Proxy Server (e.g., 10.0.0.1 or proxy.com): " host
    if [[ -z "$host" ]]; then die "Host cannot be empty."; fi

    # 2. Server Port
    read -rp "Enter Proxy Port (e.g., 8080): " port
    if [[ -z "$port" ]]; then die "Port cannot be empty."; fi

    # 3. Proxy Type
    echo -e "\nSelect Proxy Type:"
    echo "1) HTTP (default)"
    echo "2) HTTPS"
    echo "3) SOCKS4"
    echo "4) SOCKS5"
    read -rp "Choice [1-4]: " type_choice
    case "$type_choice" in
        2) type="https" ;;
        3) type="socks4" ;;
        4) type="socks5" ;;
        *) type="http" ;;
    esac

    # 4. Authentication
    read -rp "Use Authentication? [y/N]: " use_auth
    local user=""
    local pass=""
    if [[ "$use_auth" =~ ^[Yy]$ ]]; then
        read -rp "Username: " user
        read -rsp "Password: " pass
        echo ""
    fi

    # 5. Targeted Modules
    echo -e "\nAvailable Modules: ${!LOADED_MODULES[*]}"
    read -rp "Target specific module (or press Enter for 'all'): " target
    if [[ -z "$target" ]]; then target="all"; fi

    echo -e "\n${YELLOW}Summary:${NC}"
    echo "  Host: $host"
    echo "  Port: $port"
    echo "  Type: $type"
    echo "  Auth: $([[ -n "$user" ]] && echo "Yes" || echo "No")"
    echo "  Target: $target"
    echo ""

    read -rp "Apply these settings now? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Validate inputs
        if ! validate_proxy_params "$host" "$port" "$type" "$user" "$pass"; then
            die "$VALIDATION_ERROR"
        fi
        
        # Build validated URL
        local proxy_url
        proxy_url=$(build_proxy_url "$host" "$port" "$type" "$user" "$pass")
        if [[ -z "$proxy_url" ]]; then
            die "Failed to construct proxy URL"
        fi
        
        local no_proxy="localhost,127.0.0.1,::1"
        
        if [[ "$target" == "all" ]]; then
            run_module_cmd "set" "$proxy_url" "$no_proxy"
        else
            if [[ -n "${LOADED_MODULES[$target]:-}" ]]; then
                "module_${target}_set" "$proxy_url" "$no_proxy"
            else
                log "ERROR" "Module '$target' not found."
                return 1
            fi
        fi
        log "SUCCESS" "Configuration applied!"
    else
        log "INFO" "Setup cancelled."
    fi
}
