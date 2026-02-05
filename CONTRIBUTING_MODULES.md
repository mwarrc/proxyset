# Contributing Modules to ProxySet

Adding support for a new application is streamlined and modular. Each module is a standalone Bash script located in `lib/modules/`.

## Module Core Architecture

A module interacts with the ProxySet engine via three mandatory functions. Create a file named `your-app.sh` in `lib/modules/` and implement the following:

```bash
#!/bin/bash
# ProxySet Module - [Application Name]

# 1. SET: Called when 'proxyset set' is run
# Arguments:
#   $1: Fully formatted proxy URL (e.g., http://user:pass@127.0.0.1:8080)
#   $2: No-proxy list (e.g., localhost,127.0.0.1)
module_your-app_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    log "INFO" "Configuring [App] proxy..."
    
    # Implementation Logic: 
    # Usually editing a ~/.config file or running a CLI command
    # Examples:
    #   git config --global http.proxy "$proxy_url"
    #   sed -i "s|proxy=.*|proxy=$proxy_url|" ~/.myapprc
}

# 2. UNSET: Called when 'proxyset unset' is run
module_your-app_unset() {
    log "INFO" "Removing [App] proxy settings..."
    
    # Implementation Logic:
    #   git config --global --unset http.proxy
}

# 3. STATUS: Called when 'proxyset status' is run
module_your-app_status() {
    # Check if config exists and print it
    local current_proxy=$(your-app-cli config get proxy 2>/dev/null)
    
    if [[ -n "$current_proxy" ]]; then
        echo "[App] Proxy: $current_proxy"
    else
        echo "[App] Proxy: Not set"
    fi
}
```

## Mandatory Guidelines

### 1. Naming Conventions
- **Filename**: Must be lowercase, alphanumeric, and end in `.sh` (e.g., `docker.sh`).
- **Function Names**: Must strictly follow `module_<filename>_<command>`.
- **Global Variables**: Use local variables (`local var="..."`) inside functions to avoid polluting the global namespace.

### 2. Security Patterns
- **User Home**: Always use `$HOME` instead of hardcoding `/home/user`.
- **Privileges**: Use `run_sudo` if a command requires root, but avoid it if the config is in the user's home.
- **Pathing**: Use `command_exists "cmd"` before calling external binaries to prevent errors on systems where the app isn't installed.

### 3. Core Helper Library
ProxySet provides a rich set of built-in utilities for module developers:

| Helper | Description |
| :--- | :--- |
| `log "LEVEL" "msg"` | Standardized logging. Levels: `INFO`, `WARN`, `ERROR`, `SUCCESS`, `PROGRESS`. |
| `command_exists "cmd"`| Returns 0 if the command exists in PATH. |
| `run_sudo <cmd>` | Runs command as root (fails gracefully if sudo is unavailable). |
| `check_sudo` | Returns 0 if current user has sudo/root access. |
| `is_wsl` | Returns 0 if running under Windows Subsystem for Linux. |
| `get_wsl_host_ip` | Retrieves the IP of the Windows host from within WSL. |
| `parse_proxy_url "$url"`| Returns `proto\|user\|pass\|host\|port`. |
| `url_encode "$str"` | Safely encodes characters for URL strings. |
| `shell_escape "$str"` | Escapes dangerous characters for use in raw shell commands. |

## Practical Example: Git Module
```bash
module_git_set() {
    local url="$1"
    git config --global http.proxy "$url"
    git config --global https.proxy "$url"
}

module_git_unset() {
    git config --global --unset http.proxy
    git config --global --unset https.proxy
}

module_git_status() {
    echo "Git Proxy:"
    printf "  http: %s\n" "$(git config --global http.proxy || echo 'Not set')"
}
```

## Testing Your Module
Once your script is in `lib/modules/`, ProxySet automatically detects it. You can test it immediately:
1. `bash proxyset.sh list` (Check if it appears in the list)
2. `bash proxyset.sh your-app status`
3. `bash proxyset.sh your-app set 127.0.0.1 8080`
4. `bash proxyset.sh tests/run_tests.sh` (Validates syntax and interface of all modules)
