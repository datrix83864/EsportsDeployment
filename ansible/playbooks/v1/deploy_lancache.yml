#!/bin/bash
#
# LANCache Server Setup Script
# High School Esports LAN Infrastructure
#
# This script sets up LANCache using Docker containers
#
# Usage:
#   sudo ./setup.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Starting LANCache server setup..."

# Update package lists
log_info "Updating package lists..."
apt-get update

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    log_info "Installing Docker..."
    
    # Install prerequisites
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    log_success "Docker installed"
else
    log_info "Docker already installed"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    log_info "Installing Docker Compose..."
    
    # Download latest version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose installed"
else
    log_info "Docker Compose already installed"
fi

# Enable and start Docker
log_info "Enabling Docker service..."
systemctl enable docker
systemctl start docker

log_success "Docker service started"

# Create directory structure
log_info "Creating directory structure..."
mkdir -p /opt/lancache
mkdir -p /srv/lancache/data
mkdir -p /srv/lancache/logs
mkdir -p /srv/lancache/config

log_success "Directories created"

# Set permissions
log_info "Setting permissions..."
chown -R root:root /opt/lancache
chmod -R 755 /opt/lancache
chown -R nobody:nogroup /srv/lancache/data
chmod -R 755 /srv/lancache/data
chown -R nobody:nogroup /srv/lancache/logs
chmod -R 755 /srv/lancache/logs

log_success "Permissions set"

# Create monitoring scripts
log_info "Creating utility scripts..."

# Status script
cat > /usr/local/bin/lancache-status <<'SCRIPT'
#!/bin/bash
echo "LANCache Server Status"
echo "======================"
echo
echo "Docker Containers:"
docker-compose -f /opt/lancache/docker-compose.yml ps
echo
echo "Cache Storage:"
df -h /srv/lancache/data | tail -1
echo
echo "Cache Size:"
du -sh /srv/lancache/data 2>/dev/null || echo "Cache empty"
echo
echo "Active Connections:"
ss -tn | grep :80 | wc -l
SCRIPT
chmod +x /usr/local/bin/lancache-status

# Monitor script
cat > /usr/local/bin/lancache-monitor <<'SCRIPT'
#!/bin/bash
echo "LANCache Live Monitor"
echo "===================="
echo "Press Ctrl+C to exit"
echo
docker logs -f lancache --tail=50
SCRIPT
chmod +x /usr/local/bin/lancache-monitor

# Cache clear script
cat > /usr/local/bin/lancache-clear <<'SCRIPT'
#!/bin/bash
echo "WARNING: This will delete all cached content!"
read -p "Are you sure? (yes/no): " -r
if [[ $REPLY == "yes" ]]; then
    echo "Stopping LANCache..."
    cd /opt/lancache
    docker-compose down
    echo "Clearing cache..."
    rm -rf /srv/lancache/data/*
    echo "Starting LANCache..."
    docker-compose up -d
    echo "Cache cleared!"
else
    echo "Cancelled"
fi
SCRIPT
chmod +x /usr/local/bin/lancache-clear

# Logs viewer
cat > /usr/local/bin/lancache-logs <<'SCRIPT'
#!/bin/bash
tail -f /srv/lancache/logs/*.log
SCRIPT
chmod +x /usr/local/bin/lancache-logs

log_success "Utility scripts created"

# Configure firewall
if command -v ufw &> /dev/null; then
    log_info "Configuring firewall..."
    ufw allow 53/udp comment 'LANCache DNS'
    ufw allow 53/tcp comment 'LANCache DNS'
    ufw allow 80/tcp comment 'LANCache HTTP'
    ufw allow 443/tcp comment 'LANCache HTTPS'
    log_success "Firewall configured"
else
    log_warning "UFW not installed, firewall not configured"
fi

# Create systemd service for auto-start
log_info "Creating systemd service..."
cat > /etc/systemd/system/lancache.service <<'SERVICE'
[Unit]
Description=LANCache Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/lancache
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable lancache.service

log_success "Systemd service created"

# Print summary
cat << EOF

${GREEN}========================================
LANCache Server Setup Complete!
========================================${NC}

Next steps:
1. Deploy configuration using Ansible:
   ${BLUE}cd ansible && ansible-playbook playbooks/deploy_lancache.yml${NC}

2. Start LANCache:
   ${BLUE}cd /opt/lancache && docker-compose up -d${NC}

3. Verify containers are running:
   ${BLUE}lancache-status${NC}

4. Configure clients to use LANCache DNS:
   ${BLUE}Primary DNS: This server's IP${NC}

5. Test with a game download

Utility commands:
- Status: ${BLUE}lancache-status${NC}
- Monitor: ${BLUE}lancache-monitor${NC}
- View logs: ${BLUE}lancache-logs${NC}
- Clear cache: ${BLUE}lancache-clear${NC}

Configuration:
- Docker Compose: /opt/lancache/docker-compose.yml
- Cache storage: /srv/lancache/data
- Logs: /srv/lancache/logs

Pre-filling cache (optional):
- ${BLUE}/opt/lancache/prefill.sh --game fortnite${NC}
- ${BLUE}/opt/lancache/prefill.sh --all${NC}

Monitoring:
- Cache stats: http://this-server-ip:3000 (Grafana)
- Prometheus: http://this-server-ip:9090

EOF

log_success "Setup complete! Deploy with Ansible to finish."
exit 0