#!/bin/bash
# ProxySet Core - Module Loader

declare -A LOADED_MODULES

load_modules() {
    local modules_dir="$1"
    
    if [[ ! -d "$modules_dir" ]]; then
        log "WARN" "Modules directory not found: $modules_dir"
        return
    fi

    log "DEBUG" "Loading modules from $modules_dir..."
    local count=0
    for module_file in "$modules_dir"/*.sh; do
        if [[ -f "$module_file" ]]; then
            # Security: Ensure module name is alphanumeric/dash/underscore only
            local module_name
            module_name=$(basename "$module_file" .sh)
            
            if [[ ! "$module_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                log "WARN" "Skipping invalid module name: $module_name"
                continue
            fi
            
            # shellcheck source=/dev/null
            if source "$module_file"; then
                LOADED_MODULES["$module_name"]="$module_file"
                ((count++))
            else
                log "ERROR" "Failed to source module: $module_name"
            fi
        fi
    done
    log "DEBUG" "Load complete. $count modules loaded."
}

run_module_cmd() {
    local cmd="$1"
    local proxy_url="$2"
    local no_proxy="$3"
    
    for module in "${!LOADED_MODULES[@]}"; do
        local func_name="module_${module}_${cmd}"
        if declare -f "$func_name" >/dev/null; then
            # Safe execution since function name is constructed from validated module name
            log "INFO" "Executing $cmd on $module..."
            # Use 'set +e' or '|| true' to prevent script exit if one module fails
            "$func_name" "$proxy_url" "$no_proxy" || log "WARN" "Module '$module' reported failure for '$cmd'"
        fi
    done
}
