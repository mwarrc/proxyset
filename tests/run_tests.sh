#!/bin/bash
# ProxySet Unit Tests
# Validates module integrity and core functions

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$ROOT_DIR/lib"

echo "Running Tests from $ROOT_DIR..."

# Mock logging
log() { :; }

# Load core
source "$LIB_DIR/core/utils.sh"
source "$LIB_DIR/core/validation.sh"

FAIL=0

echo "---------------------------------------------------"
echo "Core Validation Tests"
echo "---------------------------------------------------"

assert_true() {
    if "$@"; then echo "  [PASS] $@"; else echo "  [FAIL] $@"; FAIL=1; fi
}
assert_false() {
    if ! "$@"; then echo "  [PASS] ! $@"; else echo "  [FAIL] ! $@"; FAIL=1; fi
}

assert_true validate_ipv4 "192.168.1.1"
assert_false validate_ipv4 "256.0.0.1"
assert_true validate_ipv6 "::1"
assert_true validate_ipv6 "2001:db8::1"
assert_true validate_hostname "example.com"
assert_false validate_hostname "-example.com"
assert_true validate_proxy_url "http://user:pass@host:8080"
assert_true validate_proxy_url "socks5://127.0.0.1:9050"
# IPv6 bracket test
assert_true validate_ipv6 "[::1]" 

echo ""
echo "---------------------------------------------------"
echo "Module Syntax Check"
echo "---------------------------------------------------"

for module in "$LIB_DIR/modules/"*.sh; do
    mod_name=$(basename "$module")
    if bash -n "$module"; then
        echo "  [PASS] Syntax $mod_name"
    else
        echo "  [FAIL] Syntax $mod_name"
        FAIL=1
    fi
done

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "SUCCESS: All tests passed."
    exit 0
else
    echo "FAILURE: Some tests failed."
    exit 1
fi
