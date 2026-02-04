#!/bin/bash
# ProxySet Module - Terraform

module_terraform_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    if ! command_exists terraform; then return 0; fi
    log "INFO" "Configuring Terraform proxy (env)..."
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    log "SUCCESS" "Terraform configured via environment variables"
}

module_terraform_unset() {
    if ! command_exists terraform; then return 0; fi
    unset HTTP_PROXY HTTPS_PROXY NO_PROXY
    log "SUCCESS" "Terraform proxy (env) unset"
}

module_terraform_status() {
    if ! command_exists terraform; then return 0; fi
    echo "Terraform:"
    echo "  HTTPS_PROXY: ${HTTPS_PROXY:-Not set}"
}
