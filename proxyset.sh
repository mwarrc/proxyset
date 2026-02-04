#!/bin/bash
# ProxySet - Modular Proxy Configuration Tool
# Version: 3.0.0-alpha
# Author: mwarrc

# Default settings
DEBUG_MODE=0

# Security: Don't set -e as module failures shouldn't crash the whole tool.
# We will use explicit error handling where needed.
set +e
set -o pipefail # Keep pipefail for better data flow validation

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CORE_DIR="$LIB_DIR/core"
MODULES_DIR="$LIB_DIR/modules"


# Load core modules (order matters - dependencies first)
source "$CORE_DIR/logger.sh"
source "$CORE_DIR/utils.sh"
source "$CORE_DIR/validation.sh"
source "$CORE_DIR/security.sh"

# Set XDG paths
CONFIG_DIR=$(get_xdg_config)
DATA_DIR=$(get_xdg_data)
CACHE_DIR=$(get_xdg_cache)
LOG_FILE="$DATA_DIR/proxyset.log"

source "$CORE_DIR/module_loader.sh"
source "$CORE_DIR/wizard.sh"
source "$CORE_DIR/installer.sh"
source "$CORE_DIR/profiles.sh"
source "$CORE_DIR/checker.sh"
source "$CORE_DIR/diagnostics.sh"
source "$CORE_DIR/audit.sh"
source "$CORE_DIR/snapshots.sh"

# Initialize
mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"
init_profiles

# Load all available modules
load_modules "$MODULES_DIR"

show_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║      PROXYSET v3.0 - ALPHA RELEASE      ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    show_banner
    echo -e "${BOLD}${WHITE}USAGE:${NC}"
    echo -e "  $0 ${DIM}[OPTIONS]${NC} ${CYAN}<target|all>${NC} ${BOLD}<command>${NC} [args...]"
    echo ""
    
    echo -e "${BOLD}${WHITE}SYSTEM COMMANDS:${NC}"
    printf "  ${CYAN}%-24s${NC} %s\n" "wizard" "Launch interactive setup utility"
    printf "  ${CYAN}%-24s${NC} %s\n" "status" "Display current module status"
    printf "  ${CYAN}%-24s${NC} %s\n" "test [url]" "Verify internet connectivity"
    printf "  ${CYAN}%-24s${NC} %s\n" "diagnose" "In-depth network leak check"
    printf "  ${CYAN}%-24s${NC} %s\n" "run <cmd>" "Execute process with proxy env"
    echo ""

    echo -e "${BOLD}${WHITE}CONFIGURATION:${NC}"
    printf "  ${CYAN}%-24s${NC} %s\n" "set <host> <port>" "Apply proxy settings to targets"
    printf "  ${CYAN}%-24s${NC} %s\n" "  [type] [user] [pass]" "  Optional: http|https|socks5, auth"
    printf "  ${CYAN}%-24s${NC} %s\n" "unset" "Remove proxy configurations"
    printf "  ${CYAN}%-24s${NC} %s\n" "pac set <url>" "Configure Proxy Auto-Config"
    echo ""

    echo -e "${BOLD}${WHITE}PROFILES:${NC}"
    printf "  ${BLUE}%-24s${NC} %s\n" "profile save <name>" "Capture current settings as profile"
    printf "  ${BLUE}%-24s${NC} %s\n" "profile load <name>" "Apply a saved configuration"
    printf "  ${BLUE}%-24s${NC} %s\n" "profile list" "Show all saved profiles"
    echo ""

    echo -e "${BOLD}${WHITE}SNAPSHOTS:${NC}"
    printf "  ${BLUE}%-24s${NC} %s\n" "snapshot save [name]" "Deep system state backup"
    printf "  ${BLUE}%-24s${NC} %s\n" "snapshot restore <name>" "Restore from a snapshot"
    printf "  ${BLUE}%-24s${NC} %s\n" "snapshot list" "List all snapshots"
    printf "  ${BLUE}%-24s${NC} %s\n" "snapshot show <name>" "View snapshot details"
    printf "  ${BLUE}%-24s${NC} %s\n" "snapshot diff <a> <b>" "Compare two snapshots"
    printf "  ${BLUE}%-24s${NC} %s\n" "snapshot delete <name>" "Remove a snapshot"
    echo ""

    echo -e "${BOLD}${WHITE}ADMIN:${NC}"
    printf "  ${PURPLE}%-24s${NC} %s\n" "audit" "Review configuration history"
    printf "  ${PURPLE}%-24s${NC} %s\n" "install" "Install ProxySet globally"
    printf "  ${PURPLE}%-24s${NC} %s\n" "update [ver] [--no-proxy]" "Update to latest or specific version"
    printf "  ${PURPLE}%-24s${NC} %s\n" "list" "Show all loaded modules"
    echo ""

    echo -e "${DIM}Modules (${#LOADED_MODULES[@]}): ${!LOADED_MODULES[*]}${NC}"
}

main() {
    if [[ $# -lt 1 ]]; then
        show_help
        exit 1
    fi

    # Global Commands that don't need target shifting
    case "$1" in
        wizard) run_wizard; exit 0 ;;
        test) check_connectivity "${2:-}"; exit 0 ;;
        diagnose) run_diagnostics; exit 0 ;;
        audit)
            case "${2:-view}" in
                verify) verify_audit ;;
                *) view_audit ;;
            esac
            exit 0
            ;;
        discover) 
            source "${LIB_DIR}/core/discovery.sh"
            run_discovery
            exit 0
            ;;
        install)
            source "${LIB_DIR}/core/installer.sh"
            module_installer_run "install"
            exit 0
            ;;
        uninstall)
            source "${LIB_DIR}/core/installer.sh"
            module_installer_run "uninstall"
            exit 0
            ;;
        update)
            source "${LIB_DIR}/core/updater.sh"
            local version=""
            local use_p=1
            shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --no-proxy) use_p=0 ;;
                    *) version="$1" ;;
                esac
                shift
            done
            module_updater_run "$version" "$use_p"
            exit 0
            ;;

        gen-man)
             source "${LIB_DIR}/core/man_gen.sh"
             generate_man_page "proxyset.1"
             exit 0
             ;;

        snapshot)
            shift
            case "${1:-list}" in
                save) take_snapshot "${2:-}"; ;;
                restore) restore_snapshot "${2:-}"; ;;
                list) list_snapshots; ;;
                show) show_snapshot "${2:-}"; ;;
                diff) diff_snapshots "${2:-}" "${3:-}"; ;;
                delete|rm) delete_snapshot "${2:-}"; ;;
                *) die "Unknown snapshot command: $1. Use: save, restore, list, show, diff, delete" ;;
            esac
            exit 0
            ;;
        run)
            shift
            if [[ $# -lt 1 ]]; then die "Command required for 'run'."; fi
            # Try to load default profile if exists or get from env
            local p_url="${http_proxy:-}"
            local n_proxy="${no_proxy:-}"
            if [[ -z "$p_url" && -f "$HOME/.config/proxyset/profiles/default.conf" ]]; then
                source "$HOME/.config/proxyset/profiles/default.conf"
                p_url="$proxy_url"
                n_proxy="$no_proxy"
            fi
            if [[ -z "$p_url" ]]; then die "No proxy configured. Set one or create a 'default' profile."; fi
            
            log "INFO" "Running command through proxy: $p_url"
            http_proxy="$p_url" https_proxy="$p_url" all_proxy="$p_url" no_proxy="$n_proxy" \
            HTTP_PROXY="$p_url" HTTPS_PROXY="$p_url" ALL_PROXY="$p_url" NO_PROXY="$n_proxy" \
            "$@"
            exit $?
            ;;
        profile)
            shift
            case "$1" in
                save)
                    shift
                    local name="${1:-}"
                    local host="${2:-}"
                    local port="${3:-}"
                    local type="${4:-http}"
                    local user="${5:-}"
                    local pass="${6:-}"
                    if [[ -z "$name" || -z "$host" || -z "$port" ]]; then die "Name, host, and port required."; fi
                    local url
                    [[ -n "$user" && -n "$pass" ]] && url="${type}://${user}:${pass}@${host}:${port}" || url="${type}://${host}:${port}"
                    save_profile "$name" "$url" "localhost,127.0.0.1,::1"
                    log_audit "profile_save" "$name" "$url"
                    ;;
                load) 
                    load_profile "${2:-}"
                    log_audit "profile_load" "${2:-}" "applied"
                    ;;
                list) list_profiles; ;;
                *) die "Unknown profile command: $1" ;;
            esac
            exit 0
            ;;
    esac

    # Check if first arg is a module name
    local target="all"
    if [[ -n "${LOADED_MODULES[$1]:-}" ]]; then
        target="$1"
        shift
    elif [[ "$1" == "all" ]]; then
        target="all"
        shift
    fi

    local command="${1:-}"
    if [[ -z "$command" && "$target" == "all" ]]; then
        show_help
        exit 1
    fi
    
    # If the user didn't specify a command but used set/unset/status as first arg
    if [[ "$command" != "set" && "$command" != "unset" && "$command" != "status" && "$command" != "list" ]]; then
         # Maybe they didn't provide a module but provided a command
         if [[ "$target" == "all" ]]; then
            command="$target"
            target="all"
         else
            # Invalid command for the module
            show_help
            exit 1
         fi
    fi
    
    [[ $# -gt 0 ]] && shift

    # Auto-snapshot before changes
    if [[ "$command" == "set" || "$command" == "unset" ]]; then
        take_snapshot "auto_pre_${command}_$(date +%H%M%S)"
    fi

    case "$command" in
        set)
            local host="${1:-}"
            local port="${2:-}"
            local type="${3:-http}"
            local user="${4:-}"
            local pass="${5:-}"
            
            # Validate all inputs before proceeding
            if ! validate_proxy_params "$host" "$port" "$type" "$user" "$pass"; then
                die "$VALIDATION_ERROR"
            fi
            
            # Build validated proxy URL
            local proxy_url
            proxy_url=$(build_proxy_url "$host" "$port" "$type" "$user" "$pass")
            if [[ -z "$proxy_url" ]]; then
                die "Failed to construct proxy URL"
            fi
            
            local no_proxy="localhost,127.0.0.1,::1"
            
            if [[ "$target" == "all" ]]; then
                run_module_cmd "set" "$proxy_url" "$no_proxy"
                echo ""
                log "INFO" "Verifying connectivity after configuration..."
                check_connectivity "http://google.com"
            else
                "module_${target}_set" "$proxy_url" "$no_proxy"
            fi
            log_audit "set" "$target" "$(sanitize_for_log "$proxy_url")"
            log "SUCCESS" "Proxy set for [$target]."
            ;;
        unset)
            if [[ "$target" == "all" ]]; then
                if [[ ${#LOADED_MODULES[@]} -eq 0 ]]; then
                    log "WARN" "No modules loaded to unset."
                fi
                run_module_cmd "unset" "" ""
            else
                "module_${target}_unset"
            fi
            log_audit "unset" "$target" "cleared"
            log "SUCCESS" "Proxy unset for [$target]."
            ;;

        pac)
            shift
            case "$1" in
                set) "module_pac_set" "$2"; log_audit "pac_set" "all" "$2" ;;
                unset) "module_pac_unset"; log_audit "pac_unset" "all" "cleared" ;;
                *) "module_pac_status" ;;
            esac
            exit 0
            ;;
        status)
            if [[ "$target" == "all" ]]; then
                if [[ ${#LOADED_MODULES[@]} -eq 0 ]]; then
                    log "WARN" "No modules loaded. Showing environment only."
                fi
                run_module_cmd "status" "" ""
                echo ""
                echo -e "${BOLD}${WHITE}Summary:${NC} ${#LOADED_MODULES[@]} modules loaded and checked."
            else
                "module_${target}_status"
            fi

            
            # Always show env status as fallback
            echo "--- System Environment ---"
            env | grep -iE "(http_proxy|https_proxy|all_proxy|no_proxy)" || echo "  No environment proxy variables detected."
            ;;

        list)
            echo "Loaded Modules:"
            for module in "${!LOADED_MODULES[@]}"; do
                echo "  - $module"
            done
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
