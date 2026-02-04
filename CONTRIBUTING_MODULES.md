# Contributing Modules to ProxySet

Adding support for a new application is easy! Each module is a standalone Bash script located in `lib/modules/`.

## Module Template

Create a file named `your-app.sh` in `lib/modules/`:

```bash
#!/bin/bash
# ProxySet Module - Your App Name

# This function is called when 'proxyset set' is run
module_your-app_set() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    # Add logic here to set proxy for your app
    # Example:
    # app-cli config set proxy "$proxy_url"
}

# This function is called when 'proxyset unset' is run
module_your-app_unset() {
    # Add logic here to remove proxy settings
}

# This function is called when 'proxyset status' is run
module_your-app_status() {
    echo "Your App Status:"
    # Show current config
}
```

## Naming Convention

- The file must end in `.sh`.
- Function names must follow the pattern: `module_<filename_without_extension>_<command>`.
- Replace `<filename_without_extension>` with your module's name (e.g., `git`, `npm`, `apt`).
- Replace `<command>` with `set`, `unset`, or `status`.

## Helper Functions

You can use core helper functions in your modules:
- `log "INFO|WARN|ERROR|SUCCESS|DEBUG" "message"`: Log a message.
- `command_exists "cmd"`: Check if a command is available.
- `check_sudo`: Check if sudo privileges are available.
- `is_wsl`: Check if running inside WSL.
- `get_wsl_host_ip`: Get the host IP from inside WSL.
```
