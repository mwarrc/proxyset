#!/bin/bash
# ProxySet Auto-Installer Script
# Usage: curl -sS https://raw.githubusercontent.com/mwarrc/proxyset/main/auto-install.sh | bash

set -euo pipefail

log() { echo -e "\033[1;34m[i]\033[0m $1"; }
success() { echo -e "\033[1;32m[v]\033[0m $1"; }
error() { echo -e "\033[1;31m[x]\033[0m $1" >&2; exit 1; }

log "Downloading ProxySet Core Distribution..."
echo -e "\033[1;31m[ALPHA] ProxySet v3.0 - ALPHA PHASE\033[0m"
echo -e "\033[2mTechnical notice: Intensive validation required across diverse environments.\033[0m"
echo ""

TEMP_DIR=$(mktemp -d)
# Use testing branch for the alpha cycle as requested by development state
git clone -b testing https://github.com/mwarrc/proxyset.git "$TEMP_DIR" > /dev/null 2>&1 || \
git clone https://github.com/mwarrc/proxyset.git "$TEMP_DIR" > /dev/null 2>&1

cd "$TEMP_DIR"

log "Running ProxySet Installer..."
if [[ -f proxyset.sh ]]; then
    chmod +x proxyset.sh
    # We call the internal install command
    sudo ./proxyset.sh install
else
    error "Installation failed: proxyset.sh not found."
fi

success "ProxySet has been installed globally."
success "Initialization complete. Run 'proxyset wizard' to begin configuration."
