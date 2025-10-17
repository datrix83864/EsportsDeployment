#!/bin/bash
#
# iPXE Boot Server Setup Script
# High School Esports LAN Infrastructure
#
# This script sets up the iPXE boot server with DHCP, TFTP, and HTTP services
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

log_info "Starting iPXE Boot Server setup..."

# Update package lists
log_info "Updating package lists..."
apt-get update

# Install required packages
log_info "Installing required packages..."
apt-get install -y \
    dnsmasq \
    tftpd-hpa \
    nginx \
    wget \
    curl \
    ipxe \
    wimtools \
    syslinux \
    pxelinux

log_success "Packages installed"

# Create directory structure
log_info "Creating directory structure..."
mkdir -p /srv/tftp
mkdir -p /srv/tftp/images
mkdir -p /srv/images/windows11
mkdir -p /var/log/ipxe

log_success "Directories created"

# Download iPXE boot files
log_info "Downloading iPXE boot files..."

# UEFI boot file
if [[ ! -f /srv/tftp/ipxe.efi ]]; then
    log_info "Downloading ipxe.efi..."
    wget -O /srv/tftp/ipxe.efi http://boot.ipxe.org/ipxe.efi || \
        cp /usr/lib/ipxe/ipxe.efi /srv/tftp/ || \
        log_warning "Could not download ipxe.efi, will need to be provided manually"
fi

# BIOS boot file
if [[ ! -f /srv/tftp/undionly.kpxe ]]; then
    log_info "Downloading undionly.kpxe..."
    wget -O /srv/tftp/undionly.kpxe http://boot.ipxe.org/undionly.kpxe || \
        cp /usr/lib/ipxe/undionly.kpxe /srv/tftp/ || \
        log_warning "Could not download undionly.kpxe, will need to be provided manually"
fi

# Download wimboot (Windows imaging boot)
if [[ ! -f /srv/tftp/wimboot ]]; then
    log_info "Downloading wimboot..."
    wget -O /srv/tftp/wimboot https://github.com/ipxe/wimboot/releases/latest/download/wimboot || \
        log_warning "Could not download wimboot, will need to be provided manually"
    chmod +x /srv/tftp/wimboot
fi

log_success "Boot files downloaded"

# Set permissions
log_info "Setting permissions..."
chown -R tftp:tftp /srv/tftp
chmod -R 755 /srv/tftp
chown -R www-data:www-data /srv/images
chmod -R 755 /srv/images

log_success "Permissions set"

# Stop default services (we'll reconfigure them)
log_info "Stopping default services..."
systemctl stop dnsmasq || true
systemctl stop tftpd-hpa || true
systemctl stop nginx || true

# Backup original configurations
log_info "Backing up original configurations..."
if [[ -f /etc/dnsmasq.conf ]]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup.$(date +%Y%m%d)
fi

if [[ -f /etc/nginx/nginx.conf ]]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d)
fi

# Configure TFTP
log_info "Configuring TFTP server..."
cat > /etc/default/tftpd-hpa <<EOF
# /etc/default/tftpd-hpa
# Configuration for TFTP server

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure --verbose"
EOF

log_success "TFTP configured"

# Note: dnsmasq.conf and nginx.conf will be deployed by Ansible
log_warning "dnsmasq.conf and nginx.conf must be deployed using Ansible playbook"
log_info "These files will be generated from your config.yaml"

# Enable and start services
log_info "Enabling services..."
systemctl enable dnsmasq
systemctl enable tftpd-hpa
systemctl enable nginx

# Create a simple test boot script
log_info "Creating test boot script..."
cat > /srv/tftp/test.ipxe <<'EOF'
#!ipxe
echo
echo =====================================
echo iPXE Boot Server Test
echo =====================================
echo
echo If you can see this message, your
echo iPXE boot server is working!
echo
echo Network Info:
echo IP: ${ip}
echo MAC: ${mac}
echo Gateway: ${gateway}
echo
echo Press any key to continue...
prompt
exit
EOF

# Configure firewall if ufw is installed
if command -v ufw &> /dev/null; then
    log_info "Configuring firewall..."
    ufw allow 67/udp comment 'DHCP'
    ufw allow 69/udp comment 'TFTP'
    ufw allow 80/tcp comment 'HTTP iPXE'
    ufw allow 8080/tcp comment 'HTTP Images'
    log_success "Firewall configured"
else
    log_warning "UFW not installed, firewall not configured"
fi

# Create monitoring script
log_info "Creating monitoring script..."
cat > /usr/local/bin/ipxe-status <<'SCRIPT'
#!/bin/bash
echo "iPXE Boot Server Status"
echo "======================="
echo
echo "Services:"
systemctl status dnsmasq --no-pager | grep Active
systemctl status tftpd-hpa --no-pager | grep Active
systemctl status nginx --no-pager | grep Active
echo
echo "DHCP Leases:"
if [[ -f /var/lib/misc/dnsmasq.leases ]]; then
    wc -l /var/lib/misc/dnsmasq.leases | awk '{print $1 " active leases"}'
else
    echo "No leases file found"
fi
echo
echo "Recent DHCP activity:"
journalctl -u dnsmasq -n 5 --no-pager | grep DHCP || echo "No recent DHCP activity"
echo
echo "Disk usage:"
df -h /srv/tftp /srv/images
SCRIPT

chmod +x /usr/local/bin/ipxe-status

# Create log rotation
log_info "Configuring log rotation..."
cat > /etc/logrotate.d/ipxe <<EOF
/var/log/dnsmasq.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 dnsmasq dnsmasq
    postrotate
        systemctl reload dnsmasq > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

# Print summary
cat << EOF

${GREEN}========================================
iPXE Boot Server Setup Complete!
========================================${NC}

Next steps:
1. Deploy configuration using Ansible:
   ${BLUE}cd ansible && ansible-playbook playbooks/deploy_ipxe.yml${NC}

2. Verify services are running:
   ${BLUE}ipxe-status${NC}

3. Test TFTP access:
   ${BLUE}tftp localhost -c get test.ipxe${NC}

4. Copy Windows image files to:
   ${BLUE}/srv/images/windows11/${NC}

5. Test PXE boot with a client machine

Configuration files needed:
- /etc/dnsmasq.conf (deployed by Ansible)
- /etc/nginx/nginx.conf (deployed by Ansible)
- /srv/tftp/boot.ipxe (deployed by Ansible)

Monitoring:
- Check status: ${BLUE}ipxe-status${NC}
- View DHCP logs: ${BLUE}journalctl -u dnsmasq -f${NC}
- View TFTP logs: ${BLUE}journalctl -u tftpd-hpa -f${NC}
- View nginx logs: ${BLUE}tail -f /var/log/nginx/access.log${NC}

Troubleshooting:
- Test DHCP: ${BLUE}nmap --script broadcast-dhcp-discover${NC}
- Test TFTP: ${BLUE}tftp localhost${NC}
- Test HTTP: ${BLUE}curl http://localhost/health${NC}

EOF

log_success "Setup complete! Configure with Ansible to finish."
exit 0