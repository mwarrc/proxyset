# Troubleshooting Guide

## Common Issues

### 1. "Command not found" after installation
If you installed locally:
- Ensure `$HOME/.local/bin` is in your `$PATH`.
- Run: `export PATH=$PATH:$HOME/.local/bin`

### 2. Sudo Password Prompts
ProxySet requires `sudo` for:
- Modifying system-wide proxy settings (`/etc/environment`).
- Configuring package managers (`apt`, `dnf`, `pacman`).
- Installing the global binary.

To avoid passwords for specific commands, edit `/etc/sudoers` (advanced users only).

### 3. GNOME vs KDE Settings
- **GNOME**: ProxySet uses `gsettings` to configure `org.gnome.system.proxy`.
- **KDE**: ProxySet modifies `kioslaverc`.
- **Issue**: If you are on a minimal window manager (i3, sway), desktop settings might not apply. Use the `env` module which sets environment variables.

### 4. Application-Specific Issues
- **Firefox**: Does not use system environment variables by default. ProxySet installs a `policies.json`. Restart Firefox after setting.
- **Docker**: Requires daemon restart. ProxySet attempts to restart `docker.service`. If you are non-root, this might fail.
- **Snap**: Requires `sudo snap set system proxy.http=...`.

### 5. Proxy Authentication Failures
- Ensure your password does not contain characters that break URL parsing (though ProxySet attempts to URL-encode them).
- Special characters in passwords should be properly escaped if passed via CLI.

## Diagnostics
Run the diagnostics tool to identify leaks or misconfigurations:
```bash
proxyset diagnose
```

## Logs
Audit logs are stored in:
- `~/.local/share/proxyset/audit.json`
