#!/bin/bash
# ProxySet Core - Interactive Wizard Module

run_wizard() {
    clear
    show_banner
    echo -e "${BOLD}${WHITE}  INTERACTIVE SETUP UTILITY${NC}"
    echo -e "${DIM}  ───────────────────────────────${NC}"
    echo ""

    # 1. Server Host
    while true; do
        read -rp "Enter Proxy Server (e.g., 10.0.0.1 or proxy.com): " host
        if [[ -z "$host" ]]; then
            log "WARN" "Host cannot be empty."
            continue
        fi
        if validate_host "$host"; then
            break
        else
            log "ERROR" "Invalid host format: '$host'"
        fi
    done

    # 2. Server Port
    while true; do
        read -rp "Enter Proxy Port (1-65535): " port
        if [[ -z "$port" ]]; then
            log "WARN" "Port cannot be empty."
            continue
        fi
        if validate_port "$port"; then
            break
        else
            log "ERROR" "Invalid port: '$port'. Must be a number between 1 and 65535."
        fi
    done

    # 3. Proxy Type
    local type=""
    while true; do
        echo -e "\nSelect Proxy Type:"
        echo "1) HTTP (default)"
        echo "2) HTTPS"
        echo "3) SOCKS4"
        echo "4) SOCKS5"
        echo "5) SOCKS5h (Remote DNS)"
        read -rp "Choice [1-5]: " type_choice
        case "$type_choice" in
            2) type="https" ;;
            3) type="socks4" ;;
            4) type="socks5" ;;
            5) type="socks5h" ;;
            1|"") type="http" ;;
            *) log "WARN" "Invalid selection: $type_choice"; continue ;;
        esac
        break
    done

    # 4. Authentication
    local user=""
    local pass=""
    while true; do
        read -rp "Use Authentication? [y/N]: " use_auth
        if [[ "$use_auth" =~ ^[Yy]$ ]]; then
            read -rp "Username: " user
            if ! validate_username "$user"; then
                log "ERROR" "Invalid username format."
                continue
            fi
            read -rsp "Password: " pass
            echo ""
            if ! validate_password "$pass"; then
                log "ERROR" "Invalid characters in password."
                continue
            fi
        elif [[ "$use_auth" =~ ^[Nn]$ || -z "$use_auth" ]]; then
            user=""
            pass=""
        else
            continue
        fi
        break
    done

    # 5. Targeted Modules
    local target=""
    while true; do
        echo -e "\nAvailable Modules: ${!LOADED_MODULES[*]}"
        read -rp "Target specific module (or press Enter for 'all'): " target
        if [[ -z "$target" || "$target" == "all" ]]; then
            target="all"
            break
        fi
        
        if [[ -n "${LOADED_MODULES[$target]:-}" ]]; then
            break
        else
            log "ERROR" "Module '$target' not found."
        fi
    done

    echo -e "\n${YELLOW}Summary:${NC}"
    echo "  Host: $host"
    echo "  Port: $port"
    echo "  Type: $type"
    echo "  Auth: $([[ -n "$user" ]] && echo "Yes" || echo "No")"
    echo "  Target: $target"
    echo ""

    read -rp "Apply these settings now? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
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
            "module_${target}_set" "$proxy_url" "$no_proxy"
        fi
        log "SUCCESS" "Configuration applied!"
    else
        log "INFO" "Setup cancelled."
    fi
}
