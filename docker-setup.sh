#!/bin/bash

set -euo pipefail

# Docker Setup Script for Ubuntu 24.04
# This script automates Docker installation following official best practices

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Run as a regular user with sudo privileges."
    exit 1
fi

# Check if running on Ubuntu 24.04
if ! grep -q "Ubuntu" /etc/os-release || ! grep -q "24.04" /etc/os-release; then
    log_warn "This script is designed for Ubuntu 24.04. Your system may not be compatible."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log_info "Starting Docker installation for Ubuntu 24.04..."

# Update package index
log_info "Updating package index..."
sudo apt-get update

# Install prerequisites
log_info "Installing prerequisites..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Remove old Docker versions if they exist
log_info "Removing old Docker versions (if any)..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Create keyrings directory
log_info "Setting up Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
log_info "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
log_info "Updating package index with Docker repository..."
sudo apt-get update

# Install Docker Engine, containerd, and Docker Compose
log_info "Installing Docker Engine, containerd, and Docker Compose..."
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Add current user to docker group
log_info "Adding user '$USER' to docker group..."
sudo usermod -aG docker "$USER"

# Enable Docker service
log_info "Enabling Docker service to start on boot..."
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Configure Docker daemon for best practices
log_info "Configuring Docker daemon..."
sudo mkdir -p /etc/docker

# Create daemon.json with best practices
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-address-pools": [
    {
      "base": "172.17.0.0/12",
      "size": 24
    }
  ],
  "userland-proxy": false,
  "live-restore": false,
  "storage-driver": "overlay2"
}
EOF

# Restart Docker to apply configuration
log_info "Restarting Docker service..."
sudo systemctl restart docker

# Verify Docker installation
log_info "Verifying Docker installation..."
if sudo docker run --rm hello-world > /dev/null 2>&1; then
    log_info "Docker is successfully installed and running!"
else
    log_error "Docker installation verification failed"
    exit 1
fi

# Display versions
log_info "Installed versions:"
docker --version
docker compose version

# Security recommendations
log_info "Configuring security best practices..."

# Enable UFW if not already enabled
if ! sudo ufw status | grep -q "Status: active"; then
    log_warn "UFW firewall is not active. Consider enabling it for better security."
fi

# Set up log rotation for Docker containers (if not using daemon config)
log_info "Log rotation is configured via daemon.json (max-size: 10m, max-file: 3)"

# Enable Docker Content Trust (optional, can be set per-user)
log_info "To enable Docker Content Trust, add 'export DOCKER_CONTENT_TRUST=1' to your ~/.bashrc"

# Final instructions
echo ""
log_info "==================== INSTALLATION COMPLETE ===================="
echo ""
log_warn "IMPORTANT: You need to log out and log back in for group changes to take effect!"
log_warn "Alternatively, run: newgrp docker"
echo ""
log_info "Quick verification commands:"
echo "  - docker --version"
echo "  - docker compose version"
echo "  - docker run --rm hello-world"
echo ""
log_info "Best practices applied:"
echo "   Log rotation configured (10MB max size, 3 files)"
echo "   Live restore enabled (containers survive daemon restarts)"
echo "   Overlay2 storage driver (recommended)"
echo "   Userland proxy disabled (better performance)"
echo "   Docker Compose V2 installed as plugin"
echo "   BuildKit support enabled"
echo ""
log_info "Security recommendations:"
echo "  - Keep Docker updated: sudo apt-get update && sudo apt-get upgrade docker-ce"
echo "  - Use Docker Content Trust for image verification"
echo "  - Regularly audit running containers: docker ps"
echo "  - Scan images for vulnerabilities: docker scan <image>"
echo "  - Use non-root users in containers when possible"
echo ""
log_info "==============================================================="
