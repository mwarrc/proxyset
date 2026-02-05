<div align="center">

# ProxySet
**Version 0.1** (Early Development)

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-black.svg?style=flat-square)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-black.svg?style=flat-square)](https://en.wikipedia.org/wiki/Linux)

---

</div>

## Installation

### Remote Installation
Deploy the latest global distribution using the automated installer.
```bash
    curl -sS https://raw.githubusercontent.com/mwarrc/proxyset/main/auto-install.sh | bash
```

### Manual Installation
Standard procedure for local deployment from source.
```bash
    # Clone the repository
    git clone https://github.com/mwarrc/proxyset.git
    cd proxyset

    # Set permissions and execute global installation
    sudo chmod +x proxyset.sh
    sudo ./proxyset.sh install
```

### For Package Maintainers
ProxySet supports standard `make` conventions for system packaging (Arch, Fedora, Debian).
```bash
    make
    sudo make install PREFIX=/usr
```

---

> [!WARNING]
> **DEVELOPMENT NOTICE**
>
> ProxySet is currently in early development. While most modules are functional across many distributions, it is not yet considered stable. Some features may break or behave unexpectedly depending on your specific system environment.
>
> **Security & Validation Protocols**
> * **Sandbox Validation**: Testing in isolated environments is mandatory prior to production use.
> * **Diagnostic Verification**: Frequent execution of the `diagnose` command is required to audit network integrity.
> * **State Management**: Rely on the engine's automated pre-flight snapshots for configuration recovery.
>
> *Operational Recommendation: Prohibit deployment in mission-critical environments until the Stable release milestone.*

---

## Command Reference

### Primary Operations
| Command | Description |
| :--- | :--- |
| `proxyset wizard` | Launch the interactive configuration utility. |
| `proxyset set <host> <port> [type]` | Apply proxy settings to all supported modules. |
| `proxyset unset` | Revert changes and purge proxy configurations. |
| `proxyset status` | Audit the current state of all local modules. |
| `proxyset diagnose` | Execute network latency and integrity verification. |

### Advanced Management
| Command | Description |
| :--- | :--- |
| `proxyset run <cmd>` | Execute a command within a proxied sub-shell. |
| `proxyset snapshot save` | Generate a system state backup. |
| `proxyset audit verify` | Validate audit log integrity (SHA256). |
| `proxyset update` | Synchronize codebase with origin. |

---

## Support Matrix

| **Category** | **Modules / Support** |
| :--- | :--- |
| **Distributions** | `Debian`, `Ubuntu`, `Fedora`, `RHEL`, `CentOS`, `Arch`, `Manjaro`, `Alpine`, `Gentoo`, `Void`, `NixOS`, `Clear Linux`, `OpenSUSE` |
| **Package Managers**| `APT`, `DNF`, `YUM`, `Pacman`, `Zypper`, `Portage`, `APK`, `XBPS`, `Nix`, `Swupd`, `Homebrew`, `Snap`, `Flatpak` |
| **Desktop Envs** | `GNOME`, `KDE Plasma`, `XFCE`, `MATE`, `Cinnamon`, `LXDE/LXQt` |
| **Dev Tools** | `Git`, `NPM`, `Yarn`, `Pip`, `Cargo`, `Go`, `Gem`, `Composer`, `Gradle`, `Maven`, `NuGet`, `Conda`, `VS Code` |
| **Cloud & Containers** | `Docker`, `Podman`, `Containerd`, `Buildah`, `Kubernetes (kubectl)`, `Helm`, `AWS CLI`, `GCloud CLI`, `Azure CLI`, `Terraform` |
| **Browsers** | `Chromium`, `Brave`, `Edge`, `Firefox` |
| **Network & DB** | `wget`, `curl`, `aria2`, `yt-dlp`, `PostgreSQL`, `MySQL/MariaDB`, `SSH` |
| **Init Systems** | `Systemd`, `OpenRC`, `Runit` |

---

## Core Features

### Architecture & Engineering
- **Modular Framework**: Isolated application logic within `lib/modules/`.
- **Standards Compliant**: Strict adherence to XDG Base Directory specifications.
- **Isolated Contexts**: Non-intrusive execution via sub-process environment injection.

### Security Architecture
- **Inert Credentials**: Automated redaction and encryption of sensitive parameters.
- **Verification Layer**: Tamper-evident audit trails with cryptographic signing.
- **Pre-flight Logic**: Mandatory state capture prior to system mutations.

---

## Technical Overview

```text
Project Structure
├── proxyset.sh           # Core Engine
├── lib/
│   ├── core/             # Framework Logic
│   └── modules/          # Application Modules
├── data/                 # Profiles and Backups
└── bin/                  # Binary Distribution
```

---

## Development

Guidelines for module creation are available in `CONTRIBUTING_MODULES.md`.

**Author**: [mwarrc](https://github.com/mwarrc)
