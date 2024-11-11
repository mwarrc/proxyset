#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to set proxy for a specific configuration file
set_proxy_for_file() {
    local file="$1"
    local proxy_url="$2"
    
    if [ -f "$file" ]; then
        sed -i '/^proxy=/d' "$file"
        echo "proxy=$proxy_url" >> "$file"
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
    sudo cp /etc/environment /etc/environment.bak
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak
    sudo cp /etc/iptables/iptables.rules /etc/iptables/iptables.rules.bak
}

# Main proxy setup function
setup_proxy() {
    read -p "Enter proxy server (e.g., proxy.example.com or 192.168.1.100): " PROXY_SERVER
    read -p "Enter proxy port: " PROXY_PORT
    read -p "Does your proxy require authentication? (y/n): " AUTH_REQUIRED

    if [[ $AUTH_REQUIRED =~ ^[Yy]$ ]]; then
        read -p "Enter username: " PROXY_USER
        read -s -p "Enter password: " PROXY_PASS
        echo  # Add a newline after the password input
        PROXY_URL="http://$PROXY_USER:$PROXY_PASS@$PROXY_SERVER:$PROXY_PORT"
    else
        PROXY_URL="http://$PROXY_SERVER:$PROXY_PORT"
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

    # Configure Pacman
    sudo sed -i 's/^#XferCommand/XferCommand/' /etc/pacman.conf
    sudo sed -i '/^XferCommand/d' /etc/pacman.conf
    echo "XferCommand = /usr/bin/curl -x $PROXY_URL -L %u -o %o" | sudo tee -a /etc/pacman.conf

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

    # Set up iptables to force all traffic through proxy
    sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to-destination $PROXY_SERVER:$PROXY_PORT
    sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j DNAT --to-destination $PROXY_SERVER:$PROXY_PORT

    # Save iptables rules
    sudo iptables-save | sudo tee /etc/iptables/iptables.rules

    # Check if iptables-persistent is installed to persist iptables rules across reboots
    if ! command_exists iptables-persistent; then
        echo "Please install iptables-persistent to ensure iptables rules are saved across reboots."
    fi

    # Enable iptables service
    sudo systemctl enable iptables.service

    # Set up transparent proxy using Python script
    setup_transparent_proxy

    # Reboot prompt
    read -p "Proxy setup complete. Would you like to reboot now? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        sudo reboot
    fi
}

# Function to set up transparent proxy using Python
setup_transparent_proxy() {
    cat << EOF > /tmp/transparent_proxy.py
import socket
import threading
import socketserver
import urllib.request
import os

class ThreadingTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    pass

class ProxyHandler(socketserver.StreamRequestHandler):
    def handle(self):
        req = self.request.recv(1024).decode('utf-8')
        first_line = req.split('\\n')[0]
        url = first_line.split(' ')[1]

        print(f"Requesting: {url}")

        proxy_handler = urllib.request.ProxyHandler({
            'http': os.environ.get('PROXY_URL'),
            'https': os.environ.get('PROXY_URL')
        })

        opener = urllib.request.build_opener(proxy_handler)
        urllib.request.install_opener(opener)

        try:
            response = urllib.request.urlopen(url)
            self.request.sendall(response.read())
        except Exception as e:
            print(f"Error: {e}")
            self.request.sendall(b"HTTP/1.1 500 Internal Server Error\\r\\n\\r\\n")

if __name__ == "__main__":
    HOST, PORT = "localhost", 8080
    with ThreadingTCPServer((HOST, PORT), ProxyHandler) as server:
        server_thread = threading.Thread(target=server.serve_forever)
        server_thread.daemon = True
        server_thread.start()
        print(f"Transparent proxy server running on {HOST}:{PORT}")
        server_thread.join()
EOF

    # Set up systemd service for the transparent proxy with environment variables
    sudo tee /etc/systemd/system/transparent-proxy.service << EOF
[Unit]
Description=Transparent Proxy Service
After=network.target

[Service]
Environment="PROXY_URL=$PROXY_URL"
ExecStart=/usr/bin/python /tmp/transparent_proxy.py
Restart=always
User=nobody
Group=nobody

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable transparent-proxy.service
    sudo systemctl start transparent-proxy.service
}

# Function to remove proxy settings
rollback_proxy() {
    echo "Rolling back proxy settings..."

    # Remove from /etc/environment
    sudo sed -i '/http_proxy/d; /https_proxy/d; /ftp_proxy/d; /no_proxy/d' /etc/environment

    # Remove environment variables
    unset http_proxy https_proxy ftp_proxy no_proxy

    # Restore Pacman configuration
    sudo sed -i 's/^XferCommand/#XferCommand/' /etc/pacman.conf
    remove_proxy_from_file "/etc/pacman.conf"

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
    sudo rm -f /etc/wgetrc

    # Remove cURL proxy settings
    remove_proxy_from_file "$HOME/.curlrc"
    sudo rm -f /etc/curlrc

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

    # Clear iptables rules related to proxy
    sudo iptables -t nat -D OUTPUT -p tcp --dport 80 -j DNAT --to-destination $PROXY_SERVER:$PROXY_PORT
    sudo iptables -t nat -D OUTPUT -p tcp --dport 443 -j DNAT --to-destination $PROXY_SERVER:$PROXY_PORT
    sudo iptables-save | sudo tee /etc/iptables/iptables.rules

    # Stop transparent proxy service
    sudo systemctl stop transparent-proxy.service
    sudo systemctl disable transparent-proxy.service
    sudo rm -f /etc/systemd/system/transparent-proxy.service
    sudo rm -f /tmp/transparent_proxy.py

    echo "Proxy settings rolled back."
}

# Main script logic
case "$1" in
    set)
        setup_proxy
        ;;
    rollback)
        rollback_proxy
        ;;
    *)
        echo "Usage: $0 {set|rollback}"
        ;;
esac
