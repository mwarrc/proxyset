<div align="center">

# ProxySet
### Advanced Modular Proxy Configuration Framework for Linux
**Version 3.0.0-Alpha**

---

</div>

> [!CAUTION]
> **OPERATIONAL NOTICE: ALPHA PHASE**
>
> ProxySet 3.0 is currently in a high-intensity development and validation cycle. While cross-distribution support is broadly implemented, environmental edge cases may exist.
>
> **Security & Validation Protocols**
> * **Sandbox Validation**: Testing in isolated environments is mandatory prior to production use.
> * **Diagnostic Verification**: Frequent execution of the `diagnose` command is required to audit network integrity.
> * **State Management**: Rely on the engine's automated pre-flight snapshots for configuration recovery.
>
> *Operational Recommendation: Prohibit deployment in mission-critical environments until the Stable release milestone.*

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

## Key Features

### Architecture & Design
- **Modular Architecture**: Application-specific logic isolated in `lib/modules/` (60+ modules)
- **XDG Compliant**: Adheres to modern Linux standards for config and data storage
- **Isolated Execution**: Temporary process-level proxying via the `run` command

### Security & Validation
- **Input Validation**: Comprehensive validation for IPv4/IPv6, hostnames, ports, URLs
- **Secure Credential Storage**: GNOME Keyring, KDE Wallet, pass, GPG integration
- **Sanitized Logging**: Automatic credential redaction in logs and audit trails
- **Audit Trail**: JSON-based audit logging with SHA256 integrity verification and GPG signing

### Snapshot & Recovery
- **Pre-Flight Snapshots**: Automated system state capture before any changes
- **Full Restore**: Complete snapshot restoration with `snapshot restore <name>`
- **Snapshot Diff**: Compare configurations between snapshots
- **Auto-Cleanup**: Configurable retention of automatic snapshots

### Container & Cloud Support
- **Deep Docker Integration**: Configures both Docker Client and Systemd Daemon proxy
- **Podman Support**: Rootless container proxy configuration
- **Cloud CLI**: AWS, Azure, Google Cloud, Terraform, Kubectl, Helm support
- **Multi-Language**: Go, Rust, Ruby, PHP, Python, Node.js, Java, .NET toolchain support

---

## Installation

### Remote Installation
```bash
curl -sS https://raw.githubusercontent.com/mwarrc/proxyset/main/auto-install.sh | bash
```

### Manual Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/mwarrc/proxyset.git
   cd proxyset
   ```
2. Execute the installer:
   ```bash
   chmod +x proxyset.sh
   ./proxyset.sh install
   ```

---

## Command Reference

### System Commands
| Command | Description |
| :--- | :--- |
| `proxyset wizard` | Launch the interactive setup utility. |
| `proxyset set <host> <port> [type] [user] [pass]` | Apply proxy settings across all active modules. |
| `proxyset unset` | Remove proxy configurations system-wide. |
| `proxyset status` | Display the current status of all modules. |
| `proxyset test [url]` | Validate internet connectivity via the configured proxy. |
| `proxyset discover` | Auto-detect proxy settings via WPAD/DNS. |
| `proxyset run <cmd>` | Execute a single process with proxy environment variables. |
| `proxyset install` | Install ProxySet globally. |
| `proxyset uninstall` | Remove ProxySet from the system. |
| `proxyset update` | Update to the latest version. |
| `proxyset gen-man` | Generate man pages. |

### Profiles & Configuration
| Command | Description |
| :--- | :--- |
| `proxyset profile save <name> <host> <port> ...` | Save current settings as a named profile. |
| `proxyset profile load <name>` | Apply a saved configuration profile. |
| `proxyset profile list` | Show all saved profiles. |

### Snapshots & Recovery
| Command | Description |
| :--- | :--- |
| `proxyset snapshot save [name]` | Create a deep system state backup. |
| `proxyset snapshot restore <name>` | Restore system from a snapshot. |
| `proxyset snapshot list` | List all available snapshots. |
| `proxyset snapshot show <name>` | View detailed snapshot information. |
| `proxyset snapshot diff <a> <b>` | Compare two snapshots. |
| `proxyset snapshot delete <name>` | Remove a snapshot. |

### Administrative Commands
| Command | Description |
| :--- | :--- |
| `proxyset diagnose` | Latency, IP leak verification, and health checks. |
| `proxyset audit` | Review the configuration change log. |
| `proxyset audit verify` | Verify integrity of audit logs. |
| `proxyset pac set <url>` | Configure Proxy Auto-Config integration. |
| `proxyset list` | Show all loaded modules. |

---

## Architecture Overview

```text
/
├── proxyset.sh           # Main Engine and CLI
├── lib/
│   ├── core/             # Core logic (Wizard, Audit, Snapshot, Validation, etc.)
│   └── modules/          # Standalone application modules (60+ files)
├── data/
│   ├── profiles/         # User-defined configurations
│   └── backups/          # System state snapshots
└── bin/                  # Installation binary
```

---

## Contribution and Development

Information regarding the creation of new modules can be found in `CONTRIBUTING_MODULES.md`.

**Author**: [mwarrc](https://github.com/mwarrc)
