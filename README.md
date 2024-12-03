
# Proxyset
Proxyset is a powerful proxy management tool designed primarily for Linux systems, with optimized support for Arch-based distributions. While intended to work across various Linux environments, full compatibility is not guaranteed for all distributions. Effortlessly configure, rollback, or monitor proxy configurations system-wide and for popular applications like Git, Pacman, and more.

🐧 Compatibility Note:

Best Performance: Arch Linux and Arch-based distributions
Recommended: systemd-based Linux distributions
Partial Support: Other Linux distributions may require system-specific adjustments

## ✨ Features
- **Proxy Management**: Set and manage system-wide and application-specific proxy settings.
- **Rollback Capability**: Easily remove all proxy configurations and restore defaults.
- **Status Check**: Display the current proxy setup for quick diagnostics.
- **Cross-Application Support**: Works with Git, NPM, Yarn, Pacman, and more.
- **Silent & Transparent Operations**: Configure silent mode and set up a transparent proxy.


## 🚀 Getting Started

### Prerequisites
- Bash (version 4.0 or higher)
- `sudo` privileges
- Installed applications (optional):
  - Git, Flatpak, NPM, Yarn

### Installation
Clone the repository and make the script executable:
```bash
git clone https://github.com/mwarrc/proxyset.git
cd proxyset
chmod +x proxyset.sh
```
### Installing as a Terminal App [optional]
1.Clone the repository
```bash
git clone https://github.com/mwarrc/proxyset.git
cd proxyset
```
2.Create a symbolic link and make it executable:
```bash
sudo ln -s "$(pwd)/proxyset.sh" /usr/local/bin/proxyset
sudo chmod +x /usr/local/bin/proxyset
```

## 🛠️ Usage

### Command Syntax
```bash
proxyset [command] [options]
```

### Commands
- **`set`**: Configure and enable proxy settings.
- **`rollback`**: Remove all proxy settings.
- **`status`**: Show the current proxy configuration.

### Options
| Option        | Description                      |
|---------------|----------------------------------|
| `-h, --help`  | Show the help message.          |
| `-v, --version` | Display the version number.     |
| `-s, --silent` | Run in silent mode.             |
| `--no-reboot` | Skip reboot prompt after setting.|


## 🖥️ Examples

- Set up a proxy with no reboot:
  ```bash
  proxyset set --no-reboot
  ```
- Rollback all proxy settings:
  ```bash
  proxyset rollback
  ```
- Display the current proxy configuration:
  ```bash
  proxyset status
  ```


## 📂 Configuration Details
Proxyset modifies configurations for:
- **Environment Variables**: `/etc/environment`
- **Pacman**: `/etc/pacman.conf`
- **Git**: Global proxy settings
- **NPM/Yarn**: Proxy management
- **System Proxies**: GNOME and other supported environments

Backup files are automatically created during setup.


## 🧑‍💻 Contributing
Contributions are welcome! Feel free to:
1. Fork the repository.
2. Create a new branch for your feature/bug fix.
3. Submit a pull request.



## 🎯 Roadmap
- [ ] Add support for more applications.
- [ ] Enhance transparent proxy functionality.
- [ ] Create a GUI wrapper.



---

Let me know if you'd like me to tweak or add anything!
