
---

# Proxy Configuration Script

This script simplifies proxy setup and management on Linux systems. It can configure proxies for various tools and applications, including system-wide settings, and provides rollback functionality.

## Features

- Set up proxies for:
  - Environment variables
  - `pacman`, `wget`, `curl`, `git`, `npm`, `yarn`, and Flatpak
  - GNOME proxy settings
  - Transparent proxy with iptables
- Rollback all proxy settings
- Transparent proxy service using a custom Python script

## Prerequisites

- Ensure `sudo` is configured for your user.
- Required tools: `iptables`, `curl`, and optional tools like `git`, `npm`, `yarn`, and Flatpak if applicable.
- Python installed for the transparent proxy feature.

## Usage

### Setting Up a Proxy
1. Run the script with the `set` option:
   ```bash
   ./proxyset.sh set
   ```
2. Follow the prompts:
   - Enter the proxy server and port.
   - Provide authentication details if required.

3. The script will:
   - Backup important files.
   - Configure proxies for supported tools and services.
   - Create a transparent proxy service if needed.

### Rolling Back Proxy Settings
To remove all proxy configurations:
```bash
./proxyset.sh rollback
```

### Example Commands
- Set up a proxy:
  ```bash
  ./proxyset.sh set
  ```
- Roll back proxy settings:
  ```bash
  ./proxyset.sh rollback
  ```

## Notes

- For transparent proxy service persistence, install `iptables-persistent`.
- Reboot may be required after setup for changes to take effect.

## Contributions
Feel free to contribute by creating pull requests or reporting issues.

:)
----
