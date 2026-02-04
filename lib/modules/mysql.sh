#!/bin/bash
# ProxySet Module - MySQL / MariaDB

module_mysql_set() {
    if ! command_exists mysql; then return 0; fi
    log "INFO" "Configuring MySQL (env)..."
    # MySQL has no native proxy config, but some drivers use envs.
    export http_proxy="$1"
    export https_proxy="$1"
    log "SUCCESS" "MySQL: Environment variables set"
}

module_mysql_unset() {
    if ! command_exists mysql; then return 0; fi
    unset http_proxy https_proxy
}

module_mysql_status() {
    if ! command_exists mysql; then return 0; fi
    echo "MySQL:"
    echo "  http_proxy: ${http_proxy:-Not set}"
}
