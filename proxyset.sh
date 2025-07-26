#!/bin/bash
# ProxySet - Advanced Linux Proxy Configuration Tool
# Version: 2.0.0 - Full support for more Distros
# Author: mwarrc (Enhanced for Zero-Error Production)


set -euo pipefail

readonly VERSION="2.0.0"
readonly SCRIPT_NAME="proxyset"
readonly CONFIG_DIR="$HOME/.config/proxyset"
readonly LOG_FILE="$HOME/.local/share/proxyset/proxyset.log"
readonly BACKUP_DIR="$HOME/.local/share/proxyset/backups"
readonly LOCK_FILE="/tmp/proxyset_$(id -u).lock"
readonly TEMP_DIR="/tmp/proxyset_$(id -u)_$$"
readonly MAX_RETRIES=3
readonly CONNECT_TIMEOUT=10

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Global variables
SILENT_MODE=0
SKIP_REBOOT=0
DRY_RUN=0
FORCE_MODE=0
CURRENT_PROFILE="default"
DEBUG_MODE=0
PROGRESS_MODE=1

# Initialize variables to prevent unbound variable errors
PROXY_SERVER=""
PROXY_PORT=""
PROXY_TYPE=""
PROXY_USER=""
PROXY_PASS=""
NO_PROXY=""
PROFILE_ARG=""

# Transaction state for atomic operations
TRANSACTION_ID=""
declare -a TRANSACTION_FILES=()
declare -a TRANSACTION_COMMANDS=()

#==============================================================================
# ENHANCED UTILITY FUNCTIONS
#==============================================================================

# Enhanced logging with levels and structured output
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}:${FUNCNAME[2]}"
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Console output based on mode and level
    if [[ $SILENT_MODE -eq 0 ]]; then
        case "$level" in
            "ERROR")   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
            "WARN")    echo -e "${YELLOW}[WARN]${NC} $message" ;;
            "INFO")    echo -e "${GREEN}[INFO]${NC} $message" ;;
            "DEBUG")   [[ $DEBUG_MODE -eq 1 ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
            "PROGRESS") echo -e "${CYAN}[PROGRESS]${NC} $message" ;;
            "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        esac
    fi
    
    # Structured log entry (sanitize sensitive data)
    local sanitized_message="$message"
    if [[ "$message" =~ (password|pass|secret|token) ]]; then
        sanitized_message=$(echo "$message" | sed 's/\(password\|pass\|secret\|token\)[[:space:]]*[=:][[:space:]]*[^[:space:]]*/\1=***REDACTED***/gi')
    fi
    
    local log_entry="[$timestamp] [$level] [$caller] $sanitized_message"
    echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
    
    # Critical errors to syslog if available
    if [[ "$level" == "ERROR" ]] && command -v logger >/dev/null 2>&1; then
        logger -t "$SCRIPT_NAME" "ERROR: $sanitized_message" 2>/dev/null || true
    fi
}

# Progress indicator for long operations
show_progress() {
    local message="$1"
    local current="${2:-0}"
    local total="${3:-100}"
    
    if [[ $PROGRESS_MODE -eq 1 && $SILENT_MODE -eq 0 ]]; then
        local percent=$((current * 100 / total))
        local bar_length=50
        local filled=$((percent * bar_length / 100))
        local empty=$((bar_length - filled))
        
        printf "\r${CYAN}[PROGRESS]${NC} $message ["
        printf "%*s" $filled | tr ' ' '='
        printf "%*s" $empty | tr ' ' '-'
        printf "] %d%%" $percent
        
        if [[ $current -eq $total ]]; then
            echo
        fi
    fi
}

# Enhanced error handling with context
die() {
    local message="$1"
    local exit_code="${2:-1}"
    local show_help="${3:-0}"
    
    log "ERROR" "$message"
    
    # Show call stack in debug mode
    if [[ $DEBUG_MODE -eq 1 ]]; then
        log "DEBUG" "Call stack:"
        local i=1
        while [[ $i -lt ${#BASH_SOURCE[@]} ]]; do
            log "DEBUG" "  $i: ${BASH_SOURCE[$i]}:${BASH_LINENO[$((i-1))]} in ${FUNCNAME[$i]}"
            ((i++))
        done
    fi
    
    cleanup
    
    if [[ $show_help -eq 1 ]]; then
        echo -e "\nUse '$SCRIPT_NAME --help' for usage information" >&2
    fi
    
    exit "$exit_code"
}

# Start a new transaction
start_transaction() {
    TRANSACTION_ID="tx_$(date +%s)_$$"
    TRANSACTION_FILES=()
    TRANSACTION_COMMANDS=()
    log "DEBUG" "Started transaction: $TRANSACTION_ID"
}

# Add file backup to transaction
add_file_to_transaction() {
    local file="$1"
    local backup_file="$TEMP_DIR/${TRANSACTION_ID}_$(basename "$file")_$(date +%s).bak"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_file" 2>/dev/null || {
            log "WARN" "Could not backup file: $file"
            return 1
        }
        TRANSACTION_FILES+=("$file:$backup_file")
        log "DEBUG" "Added file to transaction: $file -> $backup_file"
    fi
}

# Add command to transaction for rollback
add_command_to_transaction() {
    local command="$1"
    TRANSACTION_COMMANDS+=("$command")
    log "DEBUG" "Added command to transaction: $command"
}

# Commit transaction (cleanup backups)
commit_transaction() {
    if [[ -n "$TRANSACTION_ID" ]]; then
        log "DEBUG" "Committing transaction: $TRANSACTION_ID"
        
        # Remove backup files
        for file_pair in "${TRANSACTION_FILES[@]}"; do
            local backup_file="${file_pair#*:}"
            rm -f "$backup_file" 2>/dev/null || true
        done
        
        TRANSACTION_ID=""
        TRANSACTION_FILES=()
        TRANSACTION_COMMANDS=()
    fi
}

# Rollback transaction
rollback_transaction() {
    if [[ -n "$TRANSACTION_ID" ]]; then
        log "WARN" "Rolling back transaction: $TRANSACTION_ID"
        
        # Restore files
        for file_pair in "${TRANSACTION_FILES[@]}"; do
            local original_file="${file_pair%:*}"
            local backup_file="${file_pair#*:}"
            
            if [[ -f "$backup_file" ]]; then
                if cp "$backup_file" "$original_file" 2>/dev/null; then
                    log "DEBUG" "Restored file: $original_file"
                else
                    log "ERROR" "Failed to restore file: $original_file"
                fi
                rm -f "$backup_file" 2>/dev/null || true
            fi
        done
        
        # Execute rollback commands
        for command in "${TRANSACTION_COMMANDS[@]}"; do
            log "DEBUG" "Executing rollback command: $command"
            eval "$command" 2>/dev/null || log "WARN" "Rollback command failed: $command"
        done
        
        TRANSACTION_ID=""
        TRANSACTION_FILES=()
        TRANSACTION_COMMANDS=()
    fi
}

# Enhanced cleanup with transaction rollback
cleanup() {
    local exit_code=$?
    
    # Rollback transaction if active and exit code indicates failure
    if [[ -n "$TRANSACTION_ID" && $exit_code -ne 0 ]]; then
        log "WARN" "Rolling back incomplete transaction: $TRANSACTION_ID"
        rollback_transaction
    fi
    
    # Clean up temporary files
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    # Remove lock file
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE" 2>/dev/null || true
    fi
    
    # Restore terminal state
    if [[ $exit_code -ne 0 && $SILENT_MODE -eq 0 ]]; then
        echo -e "\n${RED}Operation failed with exit code: $exit_code${NC}" >&2
    fi
}

# Signal handlers with graceful shutdown
handle_signal() {
    local signal="$1"
    log "WARN" "Received signal: $signal"
    die "Script interrupted by signal $signal" 130
}

# Set up enhanced signal handlers
trap cleanup EXIT
trap 'handle_signal INT' INT
trap 'handle_signal TERM' TERM
trap 'handle_signal HUP' HUP

# Atomic lock file creation with PID validation
create_lock() {
    local max_wait=30
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        # Try to create lock atomically
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            log "DEBUG" "Lock acquired: $LOCK_FILE"
            return 0
        fi
        
        # Check if existing process is still running
        if [[ -f "$LOCK_FILE" ]]; then
            local existing_pid
            existing_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
            
            if [[ -n "$existing_pid" ]] && ! kill -0 "$existing_pid" 2>/dev/null; then
                log "WARN" "Removing stale lock file (PID: $existing_pid)"
                rm -f "$LOCK_FILE" 2>/dev/null || true
                continue
            fi
        fi
        
        log "INFO" "Waiting for lock... ($wait_time/$max_wait)"
        sleep 1
        ((wait_time++))
    done
    
    die "Could not acquire lock after ${max_wait}s. Another instance may be running."
}

# Enhanced command existence check with caching
declare -A COMMAND_CACHE
command_exists() {
    local cmd="$1"
    
    # Check cache first
    if [[ -n "${COMMAND_CACHE[$cmd]:-}" ]]; then
        return "${COMMAND_CACHE[$cmd]}"
    fi
    
    # Check command existence
    if command -v "$cmd" >/dev/null 2>&1; then
        COMMAND_CACHE[$cmd]=0
        return 0
    else
        COMMAND_CACHE[$cmd]=1
        return 1
    fi
}

# Secure sudo check with timeout
check_sudo() {
    if ! command_exists sudo; then
        log "DEBUG" "sudo not available on this system"
        return 1
    fi
    
    # Check if we can sudo without password
    if timeout 5 sudo -n true 2>/dev/null; then
        log "DEBUG" "Passwordless sudo available"
        return 0
    fi
    
    # Check if we have sudo access at all
    if ! timeout 5 sudo -v 2>/dev/null; then
        log "WARN" "Some operations require sudo access for system-wide configuration"
        if [[ $FORCE_MODE -eq 0 && $SILENT_MODE -eq 0 ]]; then
            read -p "Continue without sudo privileges? [y/N]: " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
        fi
        return 1
    fi
    
    return 0
}

# Safe directory initialization with proper permissions
init_directories() {
    local dirs=("$CONFIG_DIR" "$CONFIG_DIR/profiles" "$BACKUP_DIR" "$(dirname "$LOG_FILE")" "$TEMP_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            die "Cannot create directory: $dir"
        fi
        
        # Set secure permissions for sensitive directories
        if [[ "$dir" =~ (config|backup) ]]; then
            chmod 700 "$dir" 2>/dev/null || log "WARN" "Could not set permissions on $dir"
        fi
    done
    
    log "DEBUG" "Directories initialized successfully"
}

# Secure string escaping for shell commands
escape_string() {
    local string="$1"
    printf '%q' "$string"
}

#==============================================================================
# BACKUP AND RESTORE FUNCTIONS
#==============================================================================

# Create comprehensive backup
create_backup() {
    local backup_name="${1:-auto_$(date +%Y%m%d_%H%M%S)}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log "INFO" "Creating backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path" || die "Cannot create backup directory: $backup_path"
    
    # Backup system files
    local files_to_backup=(
        "/etc/environment"
        "/etc/apt/apt.conf.d/95proxies"
        "/etc/dnf/dnf.conf"
        "/etc/yum.conf"
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
        "$HOME/.gitconfig"
        "$HOME/.npmrc"
        "$HOME/.docker/config.json"
        "$HOME/.pip/pip.conf"
    )
    
    # Create manifest
    local manifest_file="$backup_path/manifest.txt"
    echo "# ProxySet Backup Manifest" > "$manifest_file"
    echo "# Created: $(date -Iseconds)" >> "$manifest_file"
    echo "# Version: $VERSION" >> "$manifest_file"
    echo "" >> "$manifest_file"
    
    local backup_count=0
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            local backup_file="$backup_path/$(basename "$file")"
            if cp "$file" "$backup_file" 2>/dev/null; then
                echo "$(realpath "$file"):$(basename "$file")" >> "$manifest_file"
                ((backup_count++))
                log "DEBUG" "Backed up: $file"
            else
                log "WARN" "Could not backup: $file"
            fi
        fi
    done
    
    # Backup current environment variables
    local env_backup="$backup_path/environment_vars.txt"
    {
        echo "# Environment Variables Backup"
        echo "# Created: $(date -Iseconds)"
        echo ""
        env | grep -i proxy || echo "# No proxy variables found"
    } > "$env_backup"
    
    # Update last backup reference
    echo "$backup_path" > "$CONFIG_DIR/last_backup"
    
    log "SUCCESS" "Backup created: $backup_path ($backup_count files)"
    echo "Backup location: $backup_path"
}

# Restore from backup
restore_backup() {
    local backup_path="$1"
    
    if [[ ! -d "$backup_path" ]]; then
        die "Backup directory not found: $backup_path"
    fi
    
    local manifest_file="$backup_path/manifest.txt"
    if [[ ! -f "$manifest_file" ]]; then
        die "Invalid backup: manifest file not found"
    fi
    
    log "INFO" "Restoring from backup: $backup_path"
    
    # Start transaction for rollback capability
    start_transaction
    
    local restore_count=0
    local failed_count=0
    
    # Read manifest and restore files
    while IFS=':' read -r original_path backup_file; do
        # Skip comments and empty lines
        [[ "$original_path" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$original_path" ]] && continue
        
        local full_backup_file="$backup_path/$backup_file"
        
        if [[ -f "$full_backup_file" ]]; then
            # Add current file to transaction for rollback
            add_file_to_transaction "$original_path"
            
            # Determine if sudo is needed
            local use_sudo=false
            if [[ ! -w "$original_path" ]] && [[ ! -w "$(dirname "$original_path")" ]]; then
                if check_sudo; then
                    use_sudo=true
                else
                    log "WARN" "Cannot restore $original_path (no write permission)"
                    ((failed_count++))
                    continue
                fi
            fi
            
            # Restore file
            if [[ "$use_sudo" == "true" ]]; then
                if sudo cp "$full_backup_file" "$original_path" 2>/dev/null; then
                    ((restore_count++))
                    log "DEBUG" "Restored: $original_path"
                else
                    ((failed_count++))
                    log "ERROR" "Failed to restore: $original_path"
                fi
            else
                if cp "$full_backup_file" "$original_path" 2>/dev/null; then
                    ((restore_count++))
                    log "DEBUG" "Restored: $original_path"
                else
                    ((failed_count++))
                    log "ERROR" "Failed to restore: $original_path"
                fi
            fi
        else
            log "WARN" "Backup file not found: $full_backup_file"
            ((failed_count++))
        fi
    done < "$manifest_file"
    
    if [[ $failed_count -gt 0 ]]; then
        log "WARN" "Restore completed with $failed_count failures ($restore_count successful)"
        if [[ $FORCE_MODE -eq 0 && $SILENT_MODE -eq 0 ]]; then
            read -p "Some files failed to restore. Keep changes? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                rollback_transaction
                die "Restore cancelled - changes rolled back"
            fi
        fi
    fi
    
    commit_transaction
    log "SUCCESS" "Backup restored: $restore_count files restored"
}

#==============================================================================
# ENHANCED VALIDATION FUNCTIONS
#==============================================================================

# Comprehensive proxy server validation
validate_proxy_server() {
    local server="$1"
    
    # Check basic format
    if [[ -z "$server" ]]; then
        log "ERROR" "Proxy server cannot be empty"
        return 1
    fi
    
    # Length check
    if [[ ${#server} -gt 253 ]]; then
        log "ERROR" "Proxy server name too long (max 253 characters)"
        return 1
    fi
    
    # IPv4 validation
    if [[ "$server" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        local ip=($server)
        for octet in "${ip[@]}"; do
            if [[ $octet -gt 255 ]] || [[ $octet -lt 0 ]]; then
                log "ERROR" "Invalid IPv4 address: $server"
                return 1
            fi
        done
        return 0
    fi
    
    # IPv6 validation (basic)
    if [[ "$server" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$server" == *":"* ]]; then
        return 0
    fi
    
    # Domain name validation
    if [[ "$server" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        if [[ "$server" == *.* ]]; then
            local tld="${server##*.}"
            if [[ ${#tld} -lt 2 ]] || [[ ${#tld} -gt 63 ]]; then
                log "ERROR" "Invalid TLD length in domain: $server"
                return 1
            fi
        fi
        return 0
    fi
    
    log "ERROR" "Invalid proxy server format: $server"
    return 1
}

# Enhanced port validation
validate_port() {
    local port="$1"
    
    if [[ -z "$port" ]]; then
        log "ERROR" "Port cannot be empty"
        return 1
    fi
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log "ERROR" "Port must be a number: $port"
        return 1
    fi
    
    if [[ $port -lt 1 ]] || [[ $port -gt 65535 ]]; then
        log "ERROR" "Port must be between 1-65535: $port"
        return 1
    fi
    
    return 0
}

# Enhanced proxy type validation
validate_proxy_type() {
    local type="$1"
    local valid_types=("http" "https" "socks4" "socks5")
    
    if [[ -z "$type" ]]; then
        log "ERROR" "Proxy type cannot be empty"
        return 1
    fi
    
    for valid_type in "${valid_types[@]}"; do
        if [[ "$type" == "$valid_type" ]]; then
            return 0
        fi
    done
    
    log "ERROR" "Invalid proxy type: $type (valid: ${valid_types[*]})"
    return 1
}

# Secure username validation
validate_username() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        log "ERROR" "Username cannot be empty"
        return 1
    fi
    
    if [[ ${#username} -gt 255 ]]; then
        log "ERROR" "Username too long (max 255 characters)"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-zA-Z0-9_.\@-]+$ ]]; then
        log "ERROR" "Username contains invalid characters: $username"
        return 1
    fi
    
    return 0
}

# Validate profile name
validate_profile_name() {
    local profile_name="$1"
    
    if [[ -z "$profile_name" ]]; then
        log "ERROR" "Profile name cannot be empty"
        return 1
    fi
    
    if [[ ${#profile_name} -gt 50 ]]; then
        log "ERROR" "Profile name too long (max 50 characters)"
        return 1
    fi
    
    if [[ ! "$profile_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "ERROR" "Profile name can only contain letters, numbers, underscores, and hyphens"
        return 1
    fi
    
    return 0
}

#==============================================================================
# CONFIGURATION FUNCTIONS
#==============================================================================

# Safe file update with atomic operations
safe_file_update() {
    local file="$1"
    local content="$2"
    local use_sudo="${3:-false}"
    
    log "DEBUG" "Updating file: $file"
    
    # Create secure temporary file
    local temp_file
    temp_file=$(mktemp "$TEMP_DIR/file_update.XXXXXX")
    chmod 600 "$temp_file"
    echo "$content" > "$temp_file"
    
    # Add to transaction for rollback
    add_file_to_transaction "$file"
    
    if [[ "$use_sudo" == "true" ]] && check_sudo; then
        sudo cp "$temp_file" "$file" 2>/dev/null || {
            rm -f "$temp_file"
            return 1
        }
    else
        cp "$temp_file" "$file" 2>/dev/null || {
            rm -f "$temp_file"
            return 1
        }
    fi
    
    rm -f "$temp_file"
}

# Configure environment variables
configure_environment() {
    local proxy_url="$1"
    local no_proxy="$2"
    
    log "INFO" "Configuring environment variables"
    
    # Update /etc/environment
    if [[ -w /etc/environment ]] || check_sudo; then
        local env_content=""
        
        if [[ -f /etc/environment ]]; then
            env_content=$(grep -v -E '^(http_proxy|https_proxy|ftp_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|FTP_PROXY|NO_PROXY)=' /etc/environment 2>/dev/null || echo "")
        fi
        
        env_content="${env_content}
http_proxy=\"$proxy_url\"
https_proxy=\"$proxy_url\"
ftp_proxy=\"$proxy_url\"
no_proxy=\"$no_proxy\"
HTTP_PROXY=\"$proxy_url\"
HTTPS_PROXY=\"$proxy_url\"
FTP_PROXY=\"$proxy_url\"
NO_PROXY=\"$no_proxy\""
        
        local use_sudo="false"
        if [[ ! -w /etc/environment ]] && check_sudo; then
            use_sudo="true"
        fi
        
        if ! safe_file_update "/etc/environment" "$env_content" "$use_sudo"; then
            log "WARN" "Could not update /etc/environment"
        fi
    fi
    
    # Set for current session
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    export ftp_proxy="$proxy_url"
    export no_proxy="$no_proxy"
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"
    export FTP_PROXY="$proxy_url"
    export NO_PROXY="$no_proxy"
    
    # Update shell profiles
    local shell_profiles=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    
    for profile in "${shell_profiles[@]}"; do
        if [[ -f "$profile" ]] || [[ "$profile" == "$HOME/.bashrc" ]]; then
            # Remove existing proxy exports
            if [[ -f "$profile" ]]; then
                sed -i '/^export.*_proxy=/d' "$profile" 2>/dev/null || true
                sed -i '/# Proxy settings (added by ProxySet)/d' "$profile" 2>/dev/null || true
            fi
            
            # Add new proxy settings
            local profile_content=""
            if [[ -f "$profile" ]]; then
                profile_content=$(cat "$profile")
            fi
            
            profile_content="${profile_content}

# Proxy settings (added by ProxySet v$VERSION)
export http_proxy=\"$proxy_url\"
export https_proxy=\"$proxy_url\"
export ftp_proxy=\"$proxy_url\"
export no_proxy=\"$no_proxy\"
export HTTP_PROXY=\"$proxy_url\"
export HTTPS_PROXY=\"$proxy_url\"
export FTP_PROXY=\"$proxy_url\"
export NO_PROXY=\"$no_proxy\""
            
            if ! safe_file_update "$profile" "$profile_content" "false"; then
                log "WARN" "Could not update shell profile: $profile"
            fi
        fi
    done
    
    log "SUCCESS" "Environment variables configured"
}

# Configure package managers
configure_package_managers() {
    local proxy_url="$1"
    
    log "INFO" "Configuring package managers"
    
    # APT (Debian/Ubuntu)
    if command_exists apt || command_exists apt-get; then
        local apt_conf="/etc/apt/apt.conf.d/95proxies"
        local apt_content="Acquire::http::Proxy \"$proxy_url\";
Acquire::https::Proxy \"$proxy_url\";
Acquire::ftp::Proxy \"$proxy_url\";"
        
        if [[ -d "$(dirname "$apt_conf")" ]] || check_sudo; then
            if safe_file_update "$apt_conf" "$apt_content" "true"; then
                log "DEBUG" "APT proxy configured"
            else
                log "WARN" "Could not configure APT proxy"
            fi
        fi
    fi
    
    # DNF (Fedora)
    if command_exists dnf && [[ -f /etc/dnf/dnf.conf ]]; then
        local dnf_content=""
        if [[ -f /etc/dnf/dnf.conf ]]; then
            dnf_content=$(grep -v '^proxy=' /etc/dnf/dnf.conf 2>/dev/null || cat /etc/dnf/dnf.conf 2>/dev/null)
        fi
        
        dnf_content="${dnf_content}
proxy=$proxy_url"
        
        if safe_file_update "/etc/dnf/dnf.conf" "$dnf_content" "true"; then
            log "DEBUG" "DNF proxy configured"
        else
            log "WARN" "Could not configure DNF proxy"
        fi
    fi
    
    # YUM (RHEL/CentOS)
    if command_exists yum && [[ -f /etc/yum.conf ]]; then
        local yum_content=""
        if [[ -f /etc/yum.conf ]]; then
            yum_content=$(grep -v '^proxy=' /etc/yum.conf 2>/dev/null || cat /etc/yum.conf 2>/dev/null)
        fi
        
        yum_content="${yum_content}
proxy=$proxy_url"
        
        if safe_file_update "/etc/yum.conf" "$yum_content" "true"; then
            log "DEBUG" "YUM proxy configured"
        else
            log "WARN" "Could not configure YUM proxy"
        fi
    fi
    
    log "SUCCESS" "Package managers configured"
}

# Configure development tools
configure_dev_tools() {
    local proxy_url="$1"
    
    log "INFO" "Configuring development tools"
    
    # Git
    if command_exists git; then
        if git config --global http.proxy "$proxy_url" 2>/dev/null && git config --global https.proxy "$proxy_url" 2>/dev/null; then
            log "DEBUG" "Git proxy configured"
        else
            log "WARN" "Could not configure Git proxy"
        fi
    fi
    
    # NPM
    if command_exists npm; then
        if npm config set proxy "$proxy_url" 2>/dev/null && npm config set https-proxy "$proxy_url" 2>/dev/null; then
            log "DEBUG" "NPM proxy configured"
        else
            log "WARN" "Could not configure NPM proxy"
        fi
    fi
    
    # Yarn
    if command_exists yarn; then
        if yarn config set proxy "$proxy_url" 2>/dev/null && yarn config set https-proxy "$proxy_url" 2>/dev/null; then
            log "DEBUG" "Yarn proxy configured"
        else
            log "WARN" "Could not configure Yarn proxy"
        fi
    fi
    
    # PIP (Python)
    if command_exists pip || command_exists pip3; then
        local pip_dir="$HOME/.pip"
        mkdir -p "$pip_dir"
        
        local pip_content="[global]
proxy = $proxy_url
trusted-host = pypi.org
               pypi.python.org
               files.pythonhosted.org"
        
        if safe_file_update "$pip_dir/pip.conf" "$pip_content" "false"; then
            log "DEBUG" "PIP proxy configured"
        else
            log "WARN" "Could not configure PIP proxy"
        fi
    fi
    
    # Docker
    if command_exists docker; then
        local docker_dir="$HOME/.docker"
        mkdir -p "$docker_dir"
        
        local docker_content='{
    "proxies": {
        "default": {
            "httpProxy": "'$proxy_url'",
            "httpsProxy": "'$proxy_url'"
        }
    }
}'
        
        if safe_file_update "$docker_dir/config.json" "$docker_content" "false"; then
            log "DEBUG" "Docker proxy configured"
        else
            log "WARN" "Could not configure Docker proxy"
        fi
    fi
    
    log "SUCCESS" "Development tools configured"
}

# Test proxy connection
test_proxy_connection() {
    local proxy_url="$1"
    local timeout="${2:-$CONNECT_TIMEOUT}"
    
    log "INFO" "Testing proxy connectivity..."
    
    if command_exists curl; then
        if curl -x "$proxy_url" --connect-timeout "$timeout" --silent --head --fail "http://www.google.com" >/dev/null 2>&1; then
            log "SUCCESS" "Proxy connectivity test passed"
            return 0
        fi
    fi
    
    log "ERROR" "Proxy connectivity test failed"
    return 1
}

#==============================================================================
# PROFILE MANAGEMENT
#==============================================================================

# Save current configuration to profile
save_profile() {
    local profile_name="$1"
    local proxy_server="$2"
    local proxy_port="$3"
    local proxy_type="$4"
    local proxy_user="$5"
    local no_proxy="$6"
    
    # Validate profile name
    validate_profile_name "$profile_name" || die "Invalid profile name"
    
    local profile_file="$CONFIG_DIR/profiles/$profile_name.conf"
    
    # Create secure profile content (no password stored)
    local profile_content="# ProxySet Profile: $profile_name
# Created: $(date -Iseconds)
PROXY_SERVER=$(escape_string "$proxy_server")
PROXY_PORT=$(escape_string "$proxy_port")
PROXY_TYPE=$(escape_string "$proxy_type")
PROXY_USER=$(escape_string "$proxy_user")
NO_PROXY=$(escape_string "$no_proxy")
PROFILE_VERSION=$(escape_string "$VERSION")"
    
    # Write profile with secure permissions
    if safe_file_update "$profile_file" "$profile_content" "false"; then
        chmod 600 "$profile_file" 2>/dev/null || log "WARN" "Could not set secure permissions on profile"
        log "SUCCESS" "Profile saved: $profile_name"
    else
        die "Failed to save profile: $profile_name"
    fi
}

# Load profile configuration with validation
load_profile() {
    local profile_name="$1"
    local profile_file="$CONFIG_DIR/profiles/$profile_name.conf"
    
    validate_profile_name "$profile_name" || die "Invalid profile name"
    
    if [[ ! -f "$profile_file" ]]; then
        die "Profile not found: $profile_name"
    fi
    
    # Validate profile file before sourcing
    if ! grep -q "^# ProxySet Profile:" "$profile_file" 2>/dev/null; then
        die "Invalid profile file format: $profile_name"
    fi
    
    # Source the profile safely
    local temp_vars
    temp_vars=$(mktemp "$TEMP_DIR/profile_vars.XXXXXX")
    
    # Extract only valid variable assignments
    grep '^[A-Z_][A-Z0-9_]*=' "$profile_file" > "$temp_vars" 2>/dev/null || true
    
    # Source variables
    if [[ -s "$temp_vars" ]]; then
        source "$temp_vars"
        rm -f "$temp_vars"
        log "SUCCESS" "Profile loaded: $profile_name"
    else
        rm -f "$temp_vars"
        die "Profile contains no valid configuration: $profile_name"
    fi
}

# List available profiles
list_profiles() {
    echo "Available Profiles:"
    echo "=================="
    
    if [[ ! -d "$CONFIG_DIR/profiles" ]] || [[ -z "$(ls -A "$CONFIG_DIR/profiles" 2>/dev/null)" ]]; then
        echo "No profiles found"
        return
    fi
    
    for profile_file in "$CONFIG_DIR/profiles"/*.conf; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .conf)
            
            # Extract basic info safely
            local server=""
            local port=""
            local type=""
            local created=""
            
            if [[ -f "$profile_file" ]]; then
                server=$(grep '^PROXY_SERVER=' "$profile_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'" || echo "Unknown")
                port=$(grep '^PROXY_PORT=' "$profile_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'" || echo "Unknown")
                type=$(grep '^PROXY_TYPE=' "$profile_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'" || echo "Unknown")
                created=$(grep '^# Created:' "$profile_file" 2>/dev/null | cut -d':' -f2- | xargs || echo "Unknown")
            fi
            
            printf "%-15s %s:%s (%s) - %s\n" "$profile_name" "$server" "$port" "$type" "$created"
        fi
    done
}

# Delete profile
delete_profile() {
    local profile_name="$1"
    local profile_file="$CONFIG_DIR/profiles/$profile_name.conf"
    
    validate_profile_name "$profile_name" || die "Invalid profile name"
    
    if [[ ! -f "$profile_file" ]]; then
        die "Profile not found: $profile_name"
    fi
    
    if [[ $FORCE_MODE -eq 0 && $SILENT_MODE -eq 0 ]]; then
        read -p "Delete profile '$profile_name'? [y/N]: " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    fi
    
    if rm -f "$profile_file" 2>/dev/null; then
        log "SUCCESS" "Profile deleted: $profile_name"
    else
        die "Failed to delete profile: $profile_name"
    fi
}

#==============================================================================
# MAIN FUNCTIONS
#==============================================================================

# Set proxy configuration
set_proxy() {
    local proxy_server="$1"
    local proxy_port="$2"
    local proxy_type="${3:-http}"
    local proxy_user="${4:-}"
    local proxy_pass="${5:-}"
    local no_proxy="${6:-localhost,127.0.0.1,::1}"
    
    # Validation
    validate_proxy_server "$proxy_server" || die "Invalid proxy server"
    validate_port "$proxy_port" || die "Invalid proxy port"
    validate_proxy_type "$proxy_type" || die "Invalid proxy type"
    
    if [[ -n "$proxy_user" ]]; then
        validate_username "$proxy_user" || die "Invalid proxy username"
    fi
    
    # Build proxy URL with proper encoding
    local proxy_url=""
    if [[ -n "$proxy_user" && -n "$proxy_pass" ]]; then
        # Encode credentials to prevent URL injection
        local encoded_user
        local encoded_pass
        encoded_user=$(printf '%s' "$proxy_user" | sed 's/@/%40/g; s/:/%3A/g; s/ /%20/g')
        encoded_pass=$(printf '%s' "$proxy_pass" | sed 's/@/%40/g; s/:/%3A/g; s/ /%20/g')
        proxy_url="${proxy_type}://${encoded_user}:${encoded_pass}@${proxy_server}:${proxy_port}"
    else
        proxy_url="${proxy_type}://${proxy_server}:${proxy_port}"
    fi
    
    log "INFO" "Setting proxy configuration"
    log "INFO" "Server: $proxy_server:$proxy_port"
    log "INFO" "Type: $proxy_type"
    
    # Create automatic backup before changes
    if [[ $DRY_RUN -eq 0 ]]; then
        create_backup "before_set_$(date +%Y%m%d_%H%M%S)" >/dev/null 2>&1 || log "WARN" "Could not create automatic backup"
    fi
    
    # Start transaction
    start_transaction
    
    # Test connection if not in dry run mode
    if [[ $DRY_RUN -eq 0 ]]; then
        if ! test_proxy_connection "$proxy_url"; then
            if [[ $FORCE_MODE -eq 0 ]]; then
                rollback_transaction
                die "Proxy connection test failed. Use --force to override."
            else
                log "WARN" "Proxy connection test failed, but continuing due to --force"
            fi
        fi
    fi
    
    # Apply configuration
    if [[ $DRY_RUN -eq 0 ]]; then
        local config_success=true
        
        configure_environment "$proxy_url" "$no_proxy" || config_success=false
        configure_package_managers "$proxy_url" || config_success=false
        configure_dev_tools "$proxy_url" || config_success=false
        
        if [[ "$config_success" == "false" ]]; then
            log "WARN" "Some configurations failed, but continuing..."
        fi
        
        # Save to profile if specified
        if [[ -n "$PROFILE_ARG" ]]; then
            save_profile "$PROFILE_ARG" "$proxy_server" "$proxy_port" "$proxy_type" "$proxy_user" "$no_proxy" || log "WARN" "Could not save profile"
        fi
        
        commit_transaction
        log "SUCCESS" "Proxy configuration applied successfully"
        
        if [[ $SKIP_REBOOT -eq 0 ]]; then
            log "INFO" "Some changes may require a shell restart or system reboot to take full effect"
        fi
    else
        rollback_transaction
        log "INFO" "Dry run mode - no changes applied"
    fi
}

# Remove proxy configuration
unset_proxy() {
    log "INFO" "Removing proxy configuration"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log "INFO" "Dry run mode - no changes would be applied"
        return
    fi
    
    # Create automatic backup before changes
    create_backup "before_unset_$(date +%Y%m%d_%H%M%S)" >/dev/null 2>&1 || log "WARN" "Could not create automatic backup"
    
    # Start transaction
    start_transaction
    
    # Remove environment variables
    if [[ -f /etc/environment ]]; then
        if [[ -w /etc/environment ]] || check_sudo; then
            local env_content
            env_content=$(grep -v -E '^(http_proxy|https_proxy|ftp_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|FTP_PROXY|NO_PROXY)=' /etc/environment 2>/dev/null || echo "")
            
            local use_sudo="false"
            if [[ ! -w /etc/environment ]] && check_sudo; then
                use_sudo="true"
            fi
            
            safe_file_update "/etc/environment" "$env_content" "$use_sudo" || log "WARN" "Could not update /etc/environment"
        fi
    fi
    
    # Remove from shell profiles
    local shell_profiles=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    
    for profile in "${shell_profiles[@]}"; do
        if [[ -f "$profile" ]]; then
            add_file_to_transaction "$profile"
            sed -i '/^export.*_proxy=/d' "$profile" 2>/dev/null || log "WARN" "Could not update $profile"
            sed -i '/# Proxy settings (added by ProxySet)/d' "$profile" 2>/dev/null || true
        fi
    done
    
    # Remove from package managers
    if [[ -f /etc/apt/apt.conf.d/95proxies ]]; then
        add_file_to_transaction "/etc/apt/apt.conf.d/95proxies"
        if check_sudo; then
            sudo rm -f /etc/apt/apt.conf.d/95proxies 2>/dev/null || log "WARN" "Could not remove APT proxy config"
        fi
    fi
    
    # Remove from development tools
    if command_exists git; then
        git config --global --unset http.proxy 2>/dev/null || true
        git config --global --unset https.proxy 2>/dev/null || true
    fi
    
    if command_exists npm; then
        npm config delete proxy 2>/dev/null || true
        npm config delete https-proxy 2>/dev/null || true
    fi
    
    if command_exists yarn; then
        yarn config delete proxy 2>/dev/null || true
        yarn config delete https-proxy 2>/dev/null || true
    fi
    
    if [[ -f "$HOME/.pip/pip.conf" ]]; then
        add_file_to_transaction "$HOME/.pip/pip.conf"
        rm -f "$HOME/.pip/pip.conf" 2>/dev/null || log "WARN" "Could not remove PIP proxy config"
    fi
    
    if [[ -f "$HOME/.docker/config.json" ]]; then
        add_file_to_transaction "$HOME/.docker/config.json"
        # Remove proxy configuration from Docker config
        if command_exists jq; then
            local temp_config
            temp_config=$(mktemp "$TEMP_DIR/docker_config.XXXXXX")
            jq 'del(.proxies)' "$HOME/.docker/config.json" > "$temp_config" 2>/dev/null && mv "$temp_config" "$HOME/.docker/config.json" || rm -f "$temp_config"
        else
            rm -f "$HOME/.docker/config.json" 2>/dev/null || log "WARN" "Could not remove Docker proxy config"
        fi
    fi
    
    # Unset current session variables
    unset http_proxy https_proxy ftp_proxy no_proxy 2>/dev/null || true
    unset HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY 2>/dev/null || true
    
    commit_transaction
    log "SUCCESS" "Proxy configuration removed"
}

# Show current proxy status
show_status() {
    echo "Proxy Configuration Status"
    echo "=========================="
    
    # Environment variables
    echo "Environment Variables:"
    local env_vars=("http_proxy" "https_proxy" "ftp_proxy" "no_proxy")
    for var in "${env_vars[@]}"; do
        local value="${!var:-<not set>}"
        printf "  %-12s: %s\n" "$var" "$value"
    done
    echo
    
    # System-wide configuration
    echo "System Configuration:"
    if [[ -f /etc/environment ]]; then
        if grep -E '^(http_proxy|https_proxy|ftp_proxy|no_proxy)=' /etc/environment >/dev/null 2>&1; then
            echo "  /etc/environment: ✓ Configured"
        else
            echo "  /etc/environment: ✗ Not configured"
        fi
    else
        echo "  /etc/environment: ✗ File not found"
    fi
    echo
    
    # Package managers
    echo "Package Managers:"
    
    # APT
    if [[ -f /etc/apt/apt.conf.d/95proxies ]]; then
        echo "  APT: ✓ Configured"
    else
        echo "  APT: ✗ Not configured"
    fi
    
    # DNF
    if [[ -f /etc/dnf/dnf.conf ]] && grep -q '^proxy=' /etc/dnf/dnf.conf 2>/dev/null; then
        echo "  DNF: ✓ Configured"
    else
        echo "  DNF: ✗ Not configured"
    fi
    
    # YUM
    if [[ -f /etc/yum.conf ]] && grep -q '^proxy=' /etc/yum.conf 2>/dev/null; then
        echo "  YUM: ✓ configured"
    else
        echo "  YUM: ✗ Not configured"
    fi
    echo
    
    # Development tools
    echo "Development Tools:"
    
    # Git
    if command_exists git; then
        local git_proxy
        git_proxy=$(git config --global --get http.proxy 2>/dev/null || echo "")
        if [[ -n "$git_proxy" ]]; then
            echo "  Git: ✓ Configured ($git_proxy)"
        else
            echo "  Git: ✗ Not configured"
        fi
    else
        echo "  Git: ✗ Not installed"
    fi
    
    # NPM
    if command_exists npm; then
        local npm_proxy
        npm_proxy=$(npm config get proxy 2>/dev/null || echo "")
        if [[ -n "$npm_proxy" && "$npm_proxy" != "null" ]]; then
            echo "  NPM: ✓ Configured ($npm_proxy)"
        else
            echo "  NPM: ✗ Not configured"
        fi
    else
        echo "  NPM: ✗ Not installed"
    fi
    
    # Yarn
    if command_exists yarn; then
        local yarn_proxy
        yarn_proxy=$(yarn config get proxy 2>/dev/null || echo "")
        if [[ -n "$yarn_proxy" && "$yarn_proxy" != "undefined" ]]; then
            echo "  Yarn: ✓ Configured ($yarn_proxy)"
        else
            echo "  Yarn: ✗ Not configured"
        fi
    else
        echo "  Yarn: ✗ Not installed"
    fi
    
    # PIP
    if [[ -f "$HOME/.pip/pip.conf" ]]; then
        echo "  PIP: ✓ Configured"
    else
        echo "  PIP: ✗ Not configured"
    fi
    
    # Docker
    if [[ -f "$HOME/.docker/config.json" ]]; then
        if grep -q '"proxies"' "$HOME/.docker/config.json" 2>/dev/null; then
            echo "  Docker: ✓ Configured"
        else
            echo "  Docker: ✗ Not configured"
        fi
    else
        echo "  Docker: ✗ Not configured"
    fi
}

# Interactive proxy setup
interactive_setup() {
    echo "Interactive Proxy Setup"
    echo "======================"
    echo
    
    # Get proxy server
    local proxy_server=""
    while [[ -z "$proxy_server" ]]; do
        read -p "Proxy server (IP or hostname): " proxy_server
        if ! validate_proxy_server "$proxy_server"; then
            proxy_server=""
        fi
    done
    
    # Get proxy port
    local proxy_port=""
    while [[ -z "$proxy_port" ]]; do
        read -p "Proxy port [8080]: " proxy_port
        proxy_port="${proxy_port:-8080}"
        if ! validate_port "$proxy_port"; then
            proxy_port=""
        fi
    done
    
    # Get proxy type
    echo "Proxy types: http, https, socks4, socks5"
    local proxy_type=""
    while [[ -z "$proxy_type" ]]; do
        read -p "Proxy type [http]: " proxy_type
        proxy_type="${proxy_type:-http}"
        if ! validate_proxy_type "$proxy_type"; then
            proxy_type=""
        fi
    done
    
    # Get authentication
    local proxy_user=""
    local proxy_pass=""
    read -p "Username (optional): " proxy_user
    
    if [[ -n "$proxy_user" ]]; then
        if ! validate_username "$proxy_user"; then
            proxy_user=""
        else
            read -s -p "Password: " proxy_pass
            echo
        fi
    fi
    
    # Get no_proxy
    local no_proxy=""
    read -p "No proxy hosts [localhost,127.0.0.1,::1]: " no_proxy
    no_proxy="${no_proxy:-localhost,127.0.0.1,::1}"
    
    # Get profile name
    local profile_name=""
    read -p "Save as profile (optional): " profile_name
    
    echo
    echo "Configuration Summary:"
    echo "====================="
    echo "Server: $proxy_server:$proxy_port"
    echo "Type: $proxy_type"
    echo "User: ${proxy_user:-<none>}"
    echo "No proxy: $no_proxy"
    echo "Profile: ${profile_name:-<none>}"
    echo
    
    if [[ $FORCE_MODE -eq 0 ]]; then
        read -p "Apply this configuration? [y/N]: " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    fi
    
    # Set the profile argument if provided
    if [[ -n "$profile_name" ]]; then
        PROFILE_ARG="$profile_name"
    fi
    
    # Apply configuration
    set_proxy "$proxy_server" "$proxy_port" "$proxy_type" "$proxy_user" "$proxy_pass" "$no_proxy"
}

# Show usage information
show_usage() {
    cat << EOF
ProxySet v$VERSION - Advanced Linux Proxy Configuration Tool

USAGE:
    $SCRIPT_NAME [OPTIONS] COMMAND [ARGUMENTS]

COMMANDS:
    set <server> <port> [type] [user] [pass]
        Configure proxy settings
        - server: Proxy server IP or hostname
        - port: Proxy port (1-65535)
        - type: Proxy type (http|https|socks4|socks5) [default: http]
        - user: Username for authentication (optional)
        - pass: Password for authentication (optional)

    unset
        Remove all proxy configurations

    status
        Show current proxy configuration status

    test [url]
        Test proxy connectivity
        - url: Test URL [default: http://www.google.com]

    interactive
        Interactive proxy setup wizard

    profile <command> [args]
        Profile management:
        - save <name>: Save current config as profile
        - load <name>: Load configuration from profile
        - list: List available profiles
        - delete <name>: Delete a profile

    backup [name]
        Create backup of current configuration

    restore [backup_path]
        Restore from backup

    diagnose
        Run network diagnostics

OPTIONS:
    -s, --silent        Silent mode (no output except errors)
    -f, --force         Force operation without confirmations
    -d, --dry-run       Show what would be done without applying changes
    -v, --verbose       Enable verbose/debug output
    -h, --help          Show this help message
    --version           Show version information
    --no-reboot-warn    Skip reboot warning
    --profile <name>    Save configuration to specified profile

EXAMPLES:
    # Set HTTP proxy
    $SCRIPT_NAME set proxy.company.com 8080

    # Set authenticated HTTPS proxy
    $SCRIPT_NAME set proxy.company.com 8080 https myuser mypass

    # Set proxy with profile
    $SCRIPT_NAME --profile work set proxy.company.com 8080

    # Interactive setup
    $SCRIPT_NAME interactive

    # Load from profile
    $SCRIPT_NAME profile load work

    # Check status
    $SCRIPT_NAME status

    # Remove proxy
    $SCRIPT_NAME unset

    # Test connectivity
    $SCRIPT_NAME test

    # Create backup
    $SCRIPT_NAME backup

    # Restore from backup
    $SCRIPT_NAME restore

CONFIGURATION FILES:
    - System: /etc/environment, /etc/apt/apt.conf.d/95proxies
    - User: ~/.bashrc, ~/.zshrc, ~/.profile
    - Tools: ~/.gitconfig, ~/.npmrc, ~/.docker/config.json, ~/.pip/pip.conf

LOG FILES:
    - Main log: $LOG_FILE
    - Backups: $BACKUP_DIR

NOTES:
    - Some changes require a shell restart or system reboot
    - Use 'sudo' for system-wide configurations
    - Profiles are stored in $CONFIG_DIR/profiles/
    - Backups are automatically created before major changes
    - Passwords are not stored in profiles for security

EOF
}

# Show version information
show_version() {
    cat << EOF
ProxySet v$VERSION
Advanced Linux Proxy Configuration Tool

Author: mwarrc (Enhanced for Zero-Error Production)
Repository: https://github.com/mwarrc/proxyset

System Information:
- OS: $(uname -s) $(uname -r)
- Shell: $SHELL
- User: $(whoami)
- Architecture: $(uname -m)

Configuration:
- Config Dir: $CONFIG_DIR
- Log File: $LOG_FILE
- Backup Dir: $BACKUP_DIR

Features:
- Multi-protocol support (HTTP/HTTPS/SOCKS4/SOCKS5)
- Package manager integration
- Development tools configuration
- Profile management
- Automatic backups
- Transaction rollback
- Comprehensive validation
- Network diagnostics

EOF
}

# Network diagnostics
run_diagnostics() {
    echo "Network Diagnostics Report"
    echo "========================="
    echo
    
    # System information
    echo "System Information:"
    echo "- OS: $(uname -s) $(uname -r)"
    echo "- Architecture: $(uname -m)"
    echo "- Shell: $SHELL"
    echo "- User: $(whoami)"
    echo
    
    # Network interfaces
    echo "Network Interfaces:"
    if command_exists ip; then
        ip addr show 2>/dev/null | grep -E '^[0-9]+:' | awk '{print "- " $2}' | tr -d ':'
    elif [[ -d /sys/class/net ]]; then
        for iface in /sys/class/net/*; do
            echo "- $(basename "$iface")"
        done
    fi
    echo
    
    # Default route
    echo "Default Route:"
    if command_exists ip; then
        ip route show default 2>/dev/null | head -1 | sed 's/^/- /'
    elif command_exists route; then
        route -n 2>/dev/null | grep '^0.0.0.0' | head -1 | sed 's/^/- /'
    fi
    echo
    
    # DNS servers
    echo "DNS Servers:"
    if [[ -f /etc/resolv.conf ]]; then
        grep '^nameserver' /etc/resolv.conf 2>/dev/null | sed 's/^/- /' || echo "- None configured"
    fi
    echo
    
    # Connectivity tests
    echo "Connectivity Tests:"
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    for host in "${test_hosts[@]}"; do
        if command_exists ping; then
            if timeout 3 ping -c 1 "$host" >/dev/null 2>&1; then
                echo "- ✓ $host - reachable"
            else
                echo "- ✗ $host - unreachable"
            fi
        fi
    done
    echo
    
    # Current proxy settings
    echo "Current Proxy Settings:"
    local proxy_vars=("http_proxy" "https_proxy" "ftp_proxy" "no_proxy")
    for var in "${proxy_vars[@]}"; do
        local value="${!var:-<not set>}"
        echo "- $var: $value"
    done
    echo
    
    # Available tools
    echo "Available Tools:"
    local tools=("curl" "wget" "git" "npm" "yarn" "pip" "docker" "apt" "dnf" "yum")
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            echo "- ✓ $tool"
        else
            echo "- ✗ $tool"
        fi
    done
}

#==============================================================================
# ARGUMENT PARSING AND MAIN LOGIC
#==============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--silent)
                SILENT_MODE=1
                PROGRESS_MODE=0
                shift
                ;;
            -f|--force)
                FORCE_MODE=1
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -v|--verbose)
                DEBUG_MODE=1
                shift
                ;;
            --no-reboot-warn)
                SKIP_REBOOT=1
                shift
                ;;
            --profile)
                PROFILE_ARG="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            set)
                shift
                PROXY_SERVER="${1:-}"
                PROXY_PORT="${2:-}"
                PROXY_TYPE="${3:-http}"
                PROXY_USER="${4:-}"
                PROXY_PASS="${5:-}"
                NO_PROXY="${6:-localhost,127.0.0.1,::1}"
                
                if [[ -z "$PROXY_SERVER" || -z "$PROXY_PORT" ]]; then
                    die "Usage: $SCRIPT_NAME set <server> <port> [type] [user] [pass]" 1 1
                fi
                
                set_proxy "$PROXY_SERVER" "$PROXY_PORT" "$PROXY_TYPE" "$PROXY_USER" "$PROXY_PASS" "$NO_PROXY"
                return 0
                ;;
            unset)
                unset_proxy
                return 0
                ;;
            status)
                show_status
                return 0
                ;;
            test)
                local test_url="${2:-http://www.google.com}"
                if [[ -n "${http_proxy:-}" ]]; then
                    test_proxy_connection "$http_proxy" "$CONNECT_TIMEOUT"
                else
                    log "ERROR" "No proxy configured to test"
                    return 1
                fi
                return 0
                ;;
            interactive)
                interactive_setup
                return 0
                ;;
            profile)
                shift
                local profile_cmd="${1:-}"
                case "$profile_cmd" in
                    save)
                        local profile_name="${2:-}"
                        if [[ -z "$profile_name" ]]; then
                            die "Usage: $SCRIPT_NAME profile save <name>"
                        fi
                        
                        # Get current settings from environment
                        local current_server=""
                        local current_port=""
                        local current_type="http"
                        
                        if [[ -n "${http_proxy:-}" ]]; then
                            # Parse proxy URL
                            local proxy_url="${http_proxy}"
                            current_type=$(echo "$proxy_url" | cut -d: -f1)
                            current_server=$(echo "$proxy_url" | sed 's|.*://||; s|:.*||; s|.*@||')
                            current_port=$(echo "$proxy_url" | sed 's|.*:||; s|/.*||')
                        fi
                        
                        if [[ -z "$current_server" || -z "$current_port" ]]; then
                            die "No proxy configuration found to save"
                        fi
                        
                        save_profile "$profile_name" "$current_server" "$current_port" "$current_type" "" "${NO_PROXY:-localhost,127.0.0.1,::1}"
                        ;;
                    load)
                        local profile_name="${2:-}"
                        if [[ -z "$profile_name" ]]; then
                            die "Usage: $SCRIPT_NAME profile load <name>"
                        fi
                        
                        load_profile "$profile_name"
                        set_proxy "$PROXY_SERVER" "$PROXY_PORT" "$PROXY_TYPE" "$PROXY_USER" "" "$NO_PROXY"
                        ;;
                    list)
                        list_profiles
                        ;;
                    delete)
                        local profile_name="${2:-}"
                        if [[ -z "$profile_name" ]]; then
                            die "Usage: $SCRIPT_NAME profile delete <name>"
                        fi
                        delete_profile "$profile_name"
                        ;;
                    *)
                        die "Invalid profile command. Use: save, load, list, delete" 1 1
                        ;;
                esac
                return 0
                ;;
            backup)
                local backup_name="${2:-}"
                create_backup "$backup_name"
                return 0
                ;;
            restore)
                local backup_path="${2:-}"
                if [[ -z "$backup_path" ]]; then
                    # Use latest backup
                    if [[ -f "$CONFIG_DIR/last_backup" ]]; then
                        backup_path=$(cat "$CONFIG_DIR/last_backup")
                    else
                        die "No backup specified and no recent backup found"
                    fi
                fi
                restore_backup "$backup_path"
                return 0
                ;;
            diagnose)
                run_diagnostics
                return 0
                ;;
            *)
                die "Unknown command: $1" 1 1
                ;;
        esac
    done
    
    # No command provided
    show_usage
    exit 1
}

# Main function
main() {
    # Initialize
    init_directories
    create_lock
    
    log "INFO" "ProxySet v$VERSION starting"
    log "DEBUG" "Arguments: $*"
    
    # Parse arguments and execute
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    parse_arguments "$@"
}

# Run main function with all arguments
main "$@"