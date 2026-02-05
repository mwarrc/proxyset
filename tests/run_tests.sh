#!/bin/bash
# ProxySet Quality Assurance & Test Runner
# This script performs deep analysis of all ProxySet scripts to catch bugs,
# syntax errors, and interface violations.

# --- Configuration ---
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$ROOT_DIR/lib"
CORE_DIR="$LIB_DIR/core"
MODULES_DIR="$LIB_DIR/modules"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# State
FAIL_COUNT=0
PASS_COUNT=0
TOTAL_MODULES=0

# --- Helper Functions ---
log_section() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
}

log_pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    ((PASS_COUNT++))
}

log_fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    ((FAIL_COUNT++))
}

log_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

# --- Initialization ---
# Mock logging to prevent actual log file creation during tests
log() { :; }
die() { echo -e "${RED}FATAL: $1${NC}"; exit 1; }

# Load core utilities for testing
source "$CORE_DIR/logger.sh"
source "$CORE_DIR/utils.sh"
source "$CORE_DIR/validation.sh"

log_section "Core Validation Tests"

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [[ "$actual" == "$expected" ]]; then
        log_pass "$msg"
    else
        log_fail "$msg (Expected: '$expected', Got: '$actual')"
    fi
}

assert_true() {
    if "$@"; then
        log_pass "Condition true: $1 ${2:-}"
    else
        log_fail "Condition false: $1 ${2:-}"
    fi
}

assert_false() {
    if ! "$@"; then
        log_pass "Condition false: $1 ${2:-}"
    else
        log_fail "Condition true: $1 ${2:-}"
    fi
}

# Network Validation Tests
assert_true validate_ipv4 "127.0.0.1"
assert_false validate_ipv4 "256.0.0.1"
assert_true validate_ipv6 "::1"
assert_true validate_hostname "proxy-server.internal"
assert_false validate_hostname "_invalid_.com"

# URL Parsing Tests
assert_eq "$(parse_proxy_url 'http://user:pass@host:8080')" "http|user|pass|host|8080" "Full URL parsing"
assert_eq "$(parse_proxy_url 'socks5://host:1080')" "socks5|||host|1080" "Simple URL parsing"
assert_eq "$(parse_proxy_url 'http://user:p@ss@host:80')" "http|user|p@ss|host|80" "Password with @ symbol"

log_section "Module Integrity Check"

if [[ ! -d "$MODULES_DIR" ]]; then
    die "Modules directory not found at $MODULES_DIR"
fi

for module_file in "$MODULES_DIR"/*.sh; do
    [[ ! -f "$module_file" ]] && continue
    ((TOTAL_MODULES++))
    
    module_name=$(basename "$module_file" .sh)
    echo -e "${CYAN}Analyzing module: ${BOLD}$module_name${NC}"
    
    # 1. Syntax Check
    if bash -n "$module_file" 2>/dev/null; then
        log_pass "  Syntax: OK"
    else
        log_fail "  Syntax: ERR"
        # Print actual error for debugging
        bash -n "$module_file"
    fi
    
    # 2. Interface Check (Required functions)
    # We don't source it yet to avoid side effects if it's buggy
    missing_funcs=()
    grep -q "module_${module_name}_set()" "$module_file" || missing_funcs+=("set")
    grep -q "module_${module_name}_unset()" "$module_file" || missing_funcs+=("unset")
    grep -q "module_${module_name}_status()" "$module_file" || missing_funcs+=("status")
    
    if [[ ${#missing_funcs[@]} -eq 0 ]]; then
        log_pass "  Interface: OK"
    else
        log_warn "  Interface: Missing functions: ${missing_funcs[*]}"
        # Some modules might be helper modules, but industry-grade should be consistent
    fi
    
    # 3. Execution Check (Can it be sourced with strictly defined variables?)
    # We use a subshell to avoid polluting this test runner
    if ( set -u; source "$module_file" ) >/dev/null 2>&1; then
        log_pass "  Source: OK"
    else
        log_fail "  Source: FAILED (Undefined variables or execution error)"
        # Run again without capture to see the error
        ( set -u; source "$module_file" )
    fi
done

log_section "Test Summary"
echo -e "Total Modules: $TOTAL_MODULES"
echo -e "Passes:        ${GREEN}$PASS_COUNT${NC}"
echo -e "Failures:      ${RED}$FAIL_COUNT${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "\n${RED}${BOLD}VERDICT: FAILURE${NC}"
    exit 1
else
    echo -e "\n${GREEN}${BOLD}VERDICT: SUCCESS${NC}"
    exit 0
fi
