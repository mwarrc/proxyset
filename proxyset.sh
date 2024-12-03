#!/bin/bash

VERSION="1.0.0"

# Add help and version flags
show_help() {
    cat << EOF

P R O X Y S E T 

Usage: proxyset [command] [options]

Commands:
    set         Configure and enable proxy settings
    rollback    Remove all proxy settings
    status      Show current proxy configuration

Options:
    -h, --help     Show this help message
    -v, --version  Show version number
    -s, --silent   Run in silent mode
    --no-reboot    Skip reboot prompt after setting proxy

Examples:
    proxyset set
    proxyset rollback
    proxyset status
    proxyset set --no-reboot
EOF
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to set proxy for a specific configuration file
set_proxy_for_file() {
    local file="$1"
    local proxy_url="$2"
    
    if [ -f "$file" ]; then
        sudo sed -i '/^proxy=/d' "$file"
        echo "proxy=$proxy_url" | sudo tee -a "$file" >/dev/null
    fi
}

# Function to remove proxy from a specific configuration file
remove_proxy_from_file() {
    local file="$1"
    if [ -f "$file" ]; then
        sudo sed -i '/^proxy=/d' "$file"
    fi
}

# Backup important files
backup_files() {
    if [ -f /etc/environment ]; then
        sudo cp /etc/environment /etc/environment.bak
    fi
    if [ -f /etc/pacman.conf ]; then
        sudo cp /etc/pacman.conf /etc/pacman.conf.bak
    fi
    if [ -f /etc/iptables/iptables.rules ]; then
        sudo cp /etc/iptables/iptables.rules /etc/iptables/iptables.rules.bak
    fi
}

# Add status function
show_proxy_status() {
    echo "Current Proxy Configuration:"
    echo "-------------------------"
    echo "HTTP Proxy: ${http_proxy:-Not set}"
    echo "HTTPS Proxy: ${https_proxy:-Not set}"
    echo "FTP Proxy: ${ftp_proxy:-Not set}"
    echo "No Proxy: ${no_proxy:-Not set}"
    
    echo -e "\nSystem Configurations:"
    echo "-------------------------"
    if [ -f "/etc/environment" ]; then
        echo "Environment file proxy settings:"
        grep -i "proxy" /etc/environment || echo "No proxy settings in environment file"
    fi
    
    if command_exists git; then
        echo -e "\nGit proxy settings:"
        git config --global --get http.proxy || echo "No Git HTTP proxy set"
        git config --global --get https.proxy || echo "No Git HTTPS proxy set"
    fi
}

# Main proxy setup function
setup_proxy() {
    local PROXY_SERVER PROXY_PORT AUTH_REQUIRED PROXY_USER PROXY_PASS PROXY_URL
    
    read -p "Enter proxy server (e.g., proxy.example.com or 192.168.1.100): " PROXY_SERVER
    read -p "Enter proxy port: " PROXY_PORT
    read -p "Does your proxy require authentication? (y/n): " AUTH_REQUIRED

    if [[ $AUTH_REQUIRED =~ ^[Yy]$ ]]; then
        read -p "Enter username: " PROXY_USER
        read -s -p "Enter password: " PROXY_PASS
        echo  # Add a newline after the password input
        PROXY_URL="http://${PROXY_USER}:${PROXY_PASS}@${PROXY_SERVER}:${PROXY_PORT}"
    else
        PROXY_URL="http://${PROXY_SERVER}:${PROXY_PORT}"
    fi

    # Backup important files
    backup_files

    # Set environment variables
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export ftp_proxy="$PROXY_URL"
    export no_proxy="localhost,127.0.0.1,::1"

    # Add to /etc/environment
    sudo tee -a /etc/environment << EOF
http_proxy=$PROXY_URL
https_proxy=$PROXY_URL
ftp_proxy=$PROXY_URL
no_proxy=localhost,127.0.0.1,::1
EOF

    # Configure Pacman if it exists
    if [ -f /etc/pacman.conf ]; then
        sudo sed -i 's/^#XferCommand/XferCommand/' /etc/pacman.conf
        sudo sed -i '/^XferCommand/d' /etc/pacman.conf
        echo "XferCommand = /usr/bin/curl -x $PROXY_URL -L %u -o %o" | sudo tee -a /etc/pacman.conf
    fi

    # Configure Flatpak
    if command_exists flatpak; then
        flatpak --system config --set system.proxy "$PROXY_URL"
    fi

    # Configure Git
    if command_exists git; then
        git config --global http.proxy "$PROXY_URL"
        git config --global https.proxy "$PROXY_URL"
    fi

    # Configure Wget
    set_proxy_for_file "$HOME/.wgetrc" "$PROXY_URL"

    # Configure cURL
    set_proxy_for_file "$HOME/.curlrc" "$PROXY_URL"

    # Configure NPM
    if command_exists npm; then
        npm config set proxy "$PROXY_URL"
        npm config set https-proxy "$PROXY_URL"
    fi

    # Configure Yarn
    if command_exists yarn; then
        yarn config set proxy "$PROXY_URL"
        yarn config set https-proxy "$PROXY_URL"
    fi

    # Configure system-wide GNOME proxy settings
    if command_exists gsettings; then
        gsettings set org.gnome.system.proxy mode 'manual'
        gsettings set org.gnome.system.proxy.http host "$PROXY_SERVER"
        gsettings set org.gnome.system.proxy.http port "$PROXY_PORT"
        gsettings set org.gnome.system.proxy.https host "$PROXY_SERVER"
        gsettings set org.gnome.system.proxy.https port "$PROXY_PORT"
        gsettings set org.gnome.system.proxy.ftp host "$PROXY_SERVER"
        gsettings set org.gnome.system.proxy.ftp port "$PROXY_PORT"
        if [[ $AUTH_REQUIRED =~ ^[Yy]$ ]]; then
            gsettings set org.gnome.system.proxy.http authentication-user "$PROXY_USER"
            gsettings set org.gnome.system.proxy.http authentication-password "$PROXY_PASS"
        fi
    fi

    # Set up iptables rules if iptables exists
    if command_exists iptables; then
        sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to-destination "${PROXY_SERVER}:${PROXY_PORT}"
        sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j DNAT --to-destination "${PROXY_SERVER}:${PROXY_PORT}"

        # Save iptables rules if directory exists
        if [ -d /etc/iptables ]; then
            sudo iptables-save | sudo tee /etc/iptables/iptables.rules
        fi

        # Enable iptables service if systemd exists
        if command_exists systemctl; then
            sudo systemctl enable iptables.service
        fi
    fi

    # Set up transparent proxy using Python script
    setup_transparent_proxy

    # Reboot prompt
    if [ "${SKIP_REBOOT:-0}" -eq 0 ]; then
        read -p "Proxy setup complete. Would you like to reboot now? (y/n): " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
    fi
}

# Function to set up transparent proxy using Python
setup_transparent_proxy() {
    if ! command_exists python3; then
        echo "Python3 is not installed. Skipping transparent proxy setup."
        return 1
    fi

    cat << 'EOF' > /tmp/transparent_proxy.py
import socket
import threading
import socketserver
import urllib.request
import os

class ThreadingTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True

class ProxyHandler(socketserver.StreamRequestHandler):
    def handle(self):
        try:
            req = self.request.recv(1024).decode('utf-8')
            first_line = req.split('\n')[0]
            url = first_line.split(' ')[1]

            print(f"Requesting: {url}")

            proxy_url = os.environ.get('PROXY_URL')
            if not proxy_url:
                raise ValueError("Proxy URL not set in environment")

            proxy_handler = urllib.request.ProxyHandler({
                'http': proxy_url,
                'https': proxy_url
            })

            opener = urllib.request.build_opener(proxy_handler)
            urllib.request.install_opener(opener)

            response = urllib.request.urlopen(url)
            self.request.sendall(response.read())
        except Exception as e:
            print(f"Error: {e}")
            self.request.sendall(b"HTTP/1.1 500 Internal Server Error\r\n\r\n")

if __name__ == "__main__":
    HOST, PORT = "localhost", 8080
    with ThreadingTCPServer((HOST, PORT), ProxyHandler) as server:
        server_thread = threading.Thread(target=server.serve_forever)
        server_thread.daemon = True
        server_thread.start()
        print(f"Transparent proxy server running on {HOST}:{PORT}")
        try:
            server_thread.join()
        except KeyboardInterrupt:
            server.shutdown()
EOF

    # Set up systemd service for the transparent proxy
    if command_exists systemctl; then
        sudo tee /etc/systemd/system/transparent-proxy.service << EOF
[Unit]
Description=Transparent Proxy Service
After=network.target

[Service]
Environment="PROXY_URL=$PROXY_URL"
ExecStart=/usr/bin/python3 /tmp/transparent_proxy.py
Restart=always
User=nobody
Group=nobody

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl enable transparent-proxy.service
        sudo systemctl start transparent-proxy.service
    fi
}

# Function to remove proxy settings
rollback_proxy() {
    echo "Rolling back proxy settings..."

    # Remove from /etc/environment
    if [ -f /etc/environment ]; then
        sudo sed -i '/http_proxy/d; /https_proxy/d; /ftp_proxy/d; /no_proxy/d' /etc/environment
    fi

    # Remove environment variables
    unset http_proxy https_proxy ftp_proxy no_proxy

    # Restore Pacman configuration
    if [ -f /etc/pacman.conf ]; then
        sudo sed -i 's/^XferCommand/#XferCommand/' /etc/pacman.conf
        remove_proxy_from_file "/etc/pacman.conf"
    fi

    # Remove Flatpak proxy
    if command_exists flatpak; then
        flatpak --system config --unset system.proxy
    fi

    # Remove Git proxy settings
    if command_exists git; then
        git config --global --unset http.proxy
        git config --global --unset https.proxy
    fi

    # Remove Wget proxy settings
    remove_proxy_from_file "$HOME/.wgetrc"
    if [ -f /etc/wgetrc ]; then
        sudo rm -f /etc/wgetrc
    fi

    # Remove cURL proxy settings
    remove_proxy_from_file "$HOME/.curlrc"
    if [ -f /etc/curlrc ]; then
        sudo rm -f /etc/curlrc
    fi

    # Remove NPM proxy settings
    if command_exists npm; then
        npm config delete proxy
        npm config delete https-proxy
    fi

    # Remove Yarn proxy settings
    if command_exists yarn; then
        yarn config delete proxy
        yarn config delete https-proxy
    fi

    # Remove GNOME proxy settings
    if command_exists gsettings; then
        gsettings set org.gnome.system.proxy mode 'none'
    fi

    # Clear iptables rules if iptables exists
    if command_exists iptables; then
        sudo iptables -t nat -F OUTPUT
        if [ -d /etc/iptables ]; then
            sudo iptables-save | sudo tee /etc/iptables/iptables.rules
        fi
    fi

    # Stop and remove transparent proxy service
    if command_exists systemctl; then
        sudo systemctl stop transparent-proxy.service
        sudo systemctl disable transparent-proxy.service
        sudo rm -f /etc/systemd/system/transparent-proxy.service
    fi
    sudo rm -f /tmp/transparent_proxy.py

    echo "Proxy settings rolled back successfully."
}

# Add argument parsing
parse_args() {
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "Proxyset v${VERSION}"
            exit 0
            ;;
        set)
            shift
            SKIP_REBOOT=0
            SILENT_MODE=0
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --no-reboot)
                        SKIP_REBOOT=1
                        ;;
                    -s|--silent)
                        SILENT_MODE=1
                        ;;
                    *)
                        echo "Unknown option: $1"
                        show_help
                        exit 1
                        ;;
                esac
                shift
            done
            setup_proxy
            ;;
        rollback)
            rollback_proxy
            ;;
        status)
            show_proxy_status
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Main script entry point
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    parse_args "$@"
}

# Call main with all arguments
main "$@"
