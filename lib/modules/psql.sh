#!/bin/bash
# ProxySet Module - PostgreSQL (psql)

module_psql_set() {
    if ! command_exists psql; then return 0; fi
    log "INFO" "Configuring PostgreSQL (libpq env)..."
    # libpq uses http_proxy (rarely) but mainly connection parameters.
    # Actually standard postgres doesn't support a proxy unless via Socks proxy chaining.
    # We will set ALL_PROXY for tools that use it, but note lack of native support.
    export ALL_PROXY="$1"
    log "SUCCESS" "PostgreSQL: Set ALL_PROXY (Note: psql has limited native proxy support)"
}

module_psql_unset() {
    if ! command_exists psql; then return 0; fi
    unset ALL_PROXY
}

module_psql_status() {
    if ! command_exists psql; then return 0; fi
    echo "PostgreSQL (psql):"
    echo "  ALL_PROXY: ${ALL_PROXY:-Not set}"
}
