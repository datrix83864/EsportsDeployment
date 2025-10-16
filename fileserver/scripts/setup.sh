#!/bin/bash
#
# File Server Setup Script
# High School Esports LAN Infrastructure
#
# Sets up Samba file server for roaming profiles
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

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Starting file server setup..."

# Update packages
log_info "Updating package lists..."
apt-get update

# Install Samba and dependencies
log_info "Installing Samba and dependencies..."
apt-get install -y \
    samba \
    samba-common \
    samba-common-bin \
    smbclient \
    cifs-utils \
    winbind \
    libpam-winbind \
    libnss-winbind \
    krb5-user \
    attr \
    acl

log_success "Packages installed"

# Create directory structure
log_info "Creating directory structure..."
mkdir -p /srv/profiles
mkdir -p /srv/redirected
mkdir -p /srv/documents
mkdir -p /srv/admin
mkdir -p /srv/backups
mkdir -p /srv/templates
mkdir -p /srv/public
mkdir -p /srv/netlogon

log_success "Directories created"

# Set permissions
log_info "Setting permissions..."
chmod 1777 /srv/profiles
chmod 1777 /srv/redirected
chmod 755 /srv/documents
chmod 700 /srv/admin
chmod 755 /srv/backups
chmod 755 /srv/templates
chmod 1777 /srv/public
chmod 755 /srv/netlogon

log_success "Permissions set"

# Create groups
log_info "Creating user groups..."
groupadd -f users
groupadd -f admins
groupadd -f players

log_success "Groups created"

# Backup original Samba config
if [[ -f /etc/samba/smb.conf ]]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d)
    log_info "Backed up original smb.conf"
fi

# Create default profile template
log_info "Creating default profile template..."
mkdir -p /srv/templates/default
mkdir -p /srv/templates/default/Desktop
mkdir -p /srv/templates/default/Documents
mkdir -p /srv/templates/default/Downloads

# Create welcome file
cat > /srv/templates/default/Desktop/Welcome.txt <<'EOF'
Welcome to the Esports Tournament!

Your profile is stored on the server, which means:
- You can use any computer
- Your settings will follow you
- Your keybinds and configurations are saved

Important Notes:
- Games are stored locally (not in your profile)
- Downloads go to the local G: drive
- Profile limit: 2GB (we'll warn you if you go over)

If you have issues:
- Contact tournament staff
- We can reset your profile if needed
- Your game saves are backed up

Good luck and have fun!
EOF

chmod 644 /srv/templates/default/Desktop/Welcome.txt

log_success "Profile template created"

# Stop Samba services
log_info "Stopping Samba services..."
systemctl stop smbd || true
systemctl stop nmbd || true
systemctl stop winbind || true

# Create utility scripts
log_info "Creating utility scripts..."

# Create user script
cat > /usr/local/bin/create-user <<'SCRIPT'
#!/bin/bash
if [ $# -lt 2 ]; then
    echo "Usage: create-user <username> <password>"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

# Create system user
useradd -m -G users,players -s /bin/bash "$USERNAME" 2>/dev/null || echo "User may already exist"

# Set Samba password
(echo "$PASSWORD"; echo "$PASSWORD") | smbpasswd -a "$USERNAME" -s
smbpasswd -e "$USERNAME"

# Create profile directory
mkdir -p /srv/profiles/"$USERNAME"
cp -r /srv/templates/default/* /srv/profiles/"$USERNAME"/ 2>/dev/null || true
chown -R "$USERNAME":users /srv/profiles/"$USERNAME"
chmod 700 /srv/profiles/"$USERNAME"

echo "User $USERNAME created successfully"
SCRIPT
chmod +x /usr/local/bin/create-user

# Delete user script
cat > /usr/local/bin/delete-user <<'SCRIPT'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Usage: delete-user <username>"
    exit 1
fi

USERNAME=$1

# Disable Samba user
smbpasswd -d "$USERNAME" 2>/dev/null || true

# Archive profile
if [ -d /srv/profiles/"$USERNAME" ]; then
    tar czf /srv/backups/"$USERNAME"-$(date +%Y%m%d-%H%M%S).tar.gz /srv/profiles/"$USERNAME"
    rm -rf /srv/profiles/"$USERNAME"
fi

# Delete system user
userdel -r "$USERNAME" 2>/dev/null || true

echo "User $USERNAME deleted and profile archived"
SCRIPT
chmod +x /usr/local/bin/delete-user

# Profile sizes script
cat > /usr/local/bin/profile-sizes <<'SCRIPT'
#!/bin/bash
echo "User Profile Sizes"
echo "=================="
echo

for dir in /srv/profiles/*; do
    if [ -d "$dir" ]; then
        username=$(basename "$dir")
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        size_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)
        limit_bytes=$((2 * 1024 * 1024 * 1024))  # 2GB
        
        if [ $size_bytes -gt $limit_bytes ]; then
            echo -e "$username: \033[0;31m$size (OVER LIMIT!)\033[0m"
        else
            echo "$username: $size"
        fi
    fi
done
SCRIPT
chmod +x /usr/local/bin/profile-sizes

# Status script
cat > /usr/local/bin/fileserver-status <<'SCRIPT'
#!/bin/bash
echo "File Server Status"
echo "=================="
echo

echo "Services:"
systemctl status smbd --no-pager | grep Active
systemctl status nmbd --no-pager | grep Active

echo
echo "Active Connections:"
smbstatus -b 2>/dev/null | tail -n +4 | wc -l

echo
echo "Disk Usage:"
df -h /srv | tail -1

echo
echo "Profile Storage:"
du -sh /srv/profiles 2>/dev/null || echo "Calculating..."

echo
echo "Top 5 Largest Profiles:"
du -sh /srv/profiles/* 2>/dev/null | sort -hr | head -5 || echo "No profiles yet"
SCRIPT
chmod +x /usr/local/bin/fileserver-status

# Backup script
cat > /usr/local/bin/backup-profiles <<'SCRIPT'
#!/bin/bash
BACKUP_DIR=/srv/backups
DATE=$(date +%Y%m%d)

if [ $# -eq 0 ]; then
    # Backup all profiles
    echo "Backing up all profiles..."
    tar czf "$BACKUP_DIR/all-profiles-$DATE.tar.gz" /srv/profiles
    echo "Backup complete: all-profiles-$DATE.tar.gz"
else
    # Backup specific user
    USERNAME=$1
    if [ -d "/srv/profiles/$USERNAME" ]; then
        tar czf "$BACKUP_DIR/$USERNAME-$DATE.tar.gz" /srv/profiles/"$USERNAME"
        echo "Backup complete: $USERNAME-$DATE.tar.gz"
    else
        echo "User profile not found: $USERNAME"
        exit 1
    fi
fi
SCRIPT
chmod +x /usr/local/bin/backup-profiles

# Clean profiles script
cat > /usr/local/bin/clean-profiles <<'SCRIPT'
#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: clean-profiles <username> or clean-profiles --auto"
    exit 1
fi

if [ "$1" = "--auto" ]; then
    echo "Auto-cleaning large profiles..."
    for dir in /srv/profiles/*; do
        if [ -d "$dir" ]; then
            username=$(basename "$dir")
            size_bytes=$(du -sb "$dir" | cut -f1)
            limit_bytes=$((2 * 1024 * 1024 * 1024))
            
            if [ $size_bytes -gt $limit_bytes ]; then
                echo "Cleaning $username profile..."
                find "$dir" -name "*.tmp" -delete
                find "$dir" -name "*.log" -delete
                find "$dir/AppData/Local/Temp" -type f -delete 2>/dev/null || true
                echo "  Cleaned $username"
            fi
        fi
    done
else
    USERNAME=$1
    DIR="/srv/profiles/$USERNAME"
    
    if [ ! -d "$DIR" ]; then
        echo "Profile not found: $USERNAME"
        exit 1
    fi
    
    echo "Cleaning profile: $USERNAME"
    echo "Current size: $(du -sh $DIR | cut -f1)"
    
    # Clean temp files
    find "$DIR" -name "*.tmp" -delete
    find "$DIR" -name "*.log" -delete
    find "$DIR/AppData/Local/Temp" -type f -delete 2>/dev/null || true
    find "$DIR/AppData/Local/Microsoft/Windows/Explorer" -name "*.db" -delete 2>/dev/null || true
    
    echo "New size: $(du -sh $DIR | cut -f1)"
    echo "Done!"
fi
SCRIPT
chmod +x /usr/local/bin/clean-profiles

log_success "Utility scripts created"

# Configure firewall
if command -v ufw &> /dev/null; then
    log_info "Configuring firewall..."
    ufw allow 139/tcp comment 'Samba NetBIOS'
    ufw allow 445/tcp comment 'Samba SMB'
    ufw allow 137/udp comment 'Samba NetBIOS Name'
    ufw allow 138/udp comment 'Samba NetBIOS Datagram'
    log_success "Firewall configured"
fi

# Enable services
log_info "Enabling Samba services..."
systemctl enable smbd
systemctl enable nmbd

# Print summary
cat << EOF

${GREEN}========================================
File Server Setup Complete!
========================================${NC}

Next steps:
1. Deploy Samba configuration:
   ${BLUE}cd ansible && ansible-playbook playbooks/deploy_fileserver.yml${NC}

2. Create user accounts:
   ${BLUE}create-user player1 password123${NC}

3. Test SMB access:
   ${BLUE}smbclient //localhost/profiles -U player1${NC}

4. Check status:
   ${BLUE}fileserver-status${NC}

Utility commands:
- Create user:    ${BLUE}create-user <username> <password>${NC}
- Delete user:    ${BLUE}delete-user <username>${NC}
- Profile sizes:  ${BLUE}profile-sizes${NC}
- Server status:  ${BLUE}fileserver-status${NC}
- Backup:         ${BLUE}backup-profiles [username]${NC}
- Clean profiles: ${BLUE}clean-profiles <username>${NC}

Configuration:
- Samba config: /etc/samba/smb.conf
- Profiles: /srv/profiles
- Backups: /srv/backups
- Templates: /srv/templates

EOF

log_success "Setup complete!"
exit 0