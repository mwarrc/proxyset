#!/bin/bash
# ProxySet Core - Logger Module

# Color & Style codes
readonly RED=$'\E[0;31m'
readonly GREEN=$'\E[0;32m'
readonly YELLOW=$'\E[1;33m'
readonly BLUE=$'\E[0;34m'
readonly PURPLE=$'\E[0;35m'
readonly CYAN=$'\E[0;36m'
readonly WHITE=$'\E[1;37m'
readonly BOLD=$'\E[1m'
readonly DIM=$'\E[2m'
readonly ITALIC=$'\E[3m'
readonly NC=$'\E[0m'

# Technical Symbols
readonly SYMBOL_INFO="[i]"
readonly SYMBOL_SUCCESS="[v]"
readonly SYMBOL_WARN="[!]"
readonly SYMBOL_ERROR="[x]"
readonly SYMBOL_DEBUG="[#]"

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")   echo -e "${BOLD}${RED}${SYMBOL_ERROR}${NC} ${RED}$message${NC}" >&2 ;;
        "WARN")    echo -e "${BOLD}${YELLOW}${SYMBOL_WARN}${NC} ${YELLOW}$message${NC}" ;;
        "INFO")    echo -e "${BOLD}${BLUE}${SYMBOL_INFO}${NC} $message" ;;
        "DEBUG")   [[ "${DEBUG_MODE:-0}" -eq 1 ]] && echo -e "${DIM}${SYMBOL_DEBUG} $message${NC}" ;;
        "SUCCESS") echo -e "${BOLD}${GREEN}${SYMBOL_SUCCESS}${NC} ${GREEN}$message${NC}" ;;
        "PROGRESS") echo -e "${BOLD}${CYAN}»${NC} $message" ;;
    esac
    
    # File logging (if LOG_FILE is set)
    if [[ -n "${LOG_FILE:-}" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        local sanitized_message="$message"
        if [[ "$message" =~ (password|pass|secret|token) ]]; then
            sanitized_message=$(echo "$message" | sed 's/\(password\|pass\|secret\|token\)[[:space:]]*[=:][[:space:]]*[^[:space:]]*/\1=***REDACTED***/gi')
        fi
        echo "[$timestamp] [$level] $sanitized_message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

die() {
    log "ERROR" "$1"
    exit "${2:-1}"
}
