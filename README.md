# ProxySet - Advanced Linux Proxy Configuration Tool

## Overview

**ProxySet** is a robust, feature-rich Bash script designed to simplify and secure proxy configuration management on Linux systems. It provides comprehensive proxy setup for system-wide settings, package managers, and development tools, with advanced features like profile management, backup/restore functionality, and transaction-based operations for safe configuration changes.

- **Version**: 2.0.0
- **Author**: mwarrc
- **Repository**: github.com/mwarrc/proxyset

## Features

- **Multi-Protocol Support**: Configures HTTP, HTTPS, SOCKS4, and SOCKS5 proxies.
- **System-Wide Configuration**: Updates `/etc/environment`, shell profiles (`.bashrc`, `.zshrc`, `.profile`), and more.
- **Package Manager Integration**: Supports APT, DNF, and YUM.
- **Development Tools**: Configures Git, NPM, Yarn, PIP, and Docker.
- **Profile Management**: Save, load, list, and delete proxy configuration profiles.
- **Backup and Restore**: Automatic backups before changes with reliable restore functionality.
- **Transaction Rollback**: Atomic operations with rollback support for failed configurations.
- **Comprehensive Validation**: Validates proxy server, port, type, and username inputs.
- **Network Diagnostics**: Detailed network status and connectivity tests.
- **Enhanced Logging**: Structured logging with levels (ERROR, WARN, INFO, DEBUG).
- **Progress Indicators**: Visual feedback for long-running operations.
- **Dry Run Mode**: Preview changes without applying them.
- **Force Mode**: Override confirmations and connectivity checks.
- **Silent Mode**: Minimal output for scripting purposes.
- **Secure Operations**: Sanitizes sensitive data in logs and uses secure file handling.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/mwarrc/proxyset.git
   cd proxyset
   ```

2. Make the script executable:

   ```bash
   chmod +x proxyset.sh
   ```

3. Optionally, move to a system-wide location:

   ```bash
   sudo mv proxyset.sh /usr/local/bin/proxyset
   ```

## Usage

Run the script with the desired command and options:

```bash
proxyset [OPTIONS] COMMAND [ARGUMENTS]
```

### Commands

- **set** `<server> <port> [type] [user] [pass]`: Configure proxy settings.

  - `server`: Proxy server IP or hostname.
  - `port`: Proxy port (1-65535).
  - `type`: Proxy type (http, https, socks4, socks5) \[default: http\].
  - `user`: Username for authentication (optional).
  - `pass`: Password for authentication (optional).

- **unset**: Remove all proxy configurations.

- **status**: Display current proxy configuration status.

- **test** `[url]`: Test proxy connectivity (default: http://www.google.com).

- **interactive**: Run interactive proxy setup wizard.

- **profile** `<command> [args]`:

  - `save <name>`: Save current configuration as a profile.
  - `load <name>`: Load configuration from a profile.
  - `list`: List available profiles.
  - `delete <name>`: Delete a profile.

- **backup** `[name]`: Create a backup of current configuration.

- **restore** `[backup_path]`: Restore from a specified backup (or latest if unspecified).

- **diagnose**: Run network diagnostics.

### Options

- `-s`, `--silent`: Silent mode (no output except errors).
- `-f`, `--force`: Force operation without confirmations.
- `-d`, `--dry-run`: Show changes without applying them.
- `-v`, `--verbose`: Enable debug output.
- `--no-reboot-warn`: Skip reboot warning.
- `--profile <name>`: Save configuration to specified profile.
- `-h`, `--help`: Show help message.
- `--version`: Show version information.

### Examples

```bash
# Set HTTP proxy
proxyset set proxy.company.com 8080

# Set authenticated HTTPS proxy
proxyset set proxy.company.com 8080 https myuser mypass

# Set proxy and save to profile
proxyset --profile work set proxy.company.com 8080

# Interactive setup
proxyset interactive

# Load from profile
proxyset profile load work

# Check status
proxyset status

# Remove proxy
proxyset unset

# Test connectivity
proxyset test

# Create backup
proxyset backup mybackup

# Restore from backup
proxyset restore ~/.local/share/proxyset/backups/mybackup

# Run diagnostics
proxyset diagnose
```

## Configuration Files

- **System**:

  - `/etc/environment`
  - `/etc/apt/apt.conf.d/95proxies` (APT)
  - `/etc/dnf/dnf.conf` (DNF)
  - `/etc/yum.conf` (YUM)

- **User**:

  - `~/.bashrc`
  - `~/.zshrc`
  - `~/.profile`
  - `~/.gitconfig` (Git)
  - `~/.npmrc` (NPM)
  - `~/.docker/config.json` (Docker)
  - `~/.pip/pip.conf` (PIP)

- **ProxySet**:

  - Configuration: `~/.config/proxyset/profiles/`
  - Logs: `~/.local/share/proxyset/proxyset.log`
  - Backups: `~/.local/share/proxyset/backups/`

## Notes

- **Reboot Requirement**: Some changes may require a shell restart or system reboot to take effect.
- **Sudo Access**: System-wide configurations may require `sudo` privileges.
- **Security**: Passwords are not stored in profiles and are redacted in logs.
- **Backups**: Automatic backups are created before major changes.
- **Error Handling**: The script uses transactions to ensure safe operations with rollback capability.

## Logging

Logs are stored in `~/.local/share/proxyset/proxyset.log` with structured entries including timestamp, level, caller, and message. Sensitive data (passwords, tokens) is redacted.

## Requirements

- Bash 4.0 or higher
- Common Linux utilities: `curl`, `sed`, `grep`, `awk`
- Optional: `sudo`, `ip`, `ping`, `jq` (for Docker configuration)

## Contributing

Contributions are welcome! Please submit issues or pull requests to the GitHub repository.

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -m "Add your feature"`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

## Support

For issues, feature requests, or questions, please open an issue on the GitHub repository.

---

*Last updated: July 26, 2025*

```
 https://ko-fi.com/mwarrc
 ```