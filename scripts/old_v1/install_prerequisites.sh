#!/bin/bash
#
# Install Prerequisites for Esports Infrastructure
# Installs Ansible, Terraform, and other required tools
#
# Usage:
#   sudo ./install_prerequisites.sh
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    log_error "Cannot detect OS. /etc/os-release not found."
    exit 1
fi

log_info "Detected OS: $OS $VER"

banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║  Installing Prerequisites                             ║
║  - Ansible                                            ║
║  - Terraform                                          ║
║  - Python tools                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo ""
}

banner

# Update package lists
log_info "Updating package lists..."
case $OS in
    ubuntu|debian)
        apt-get update
        ;;
    fedora|rhel|centos)
        dnf check-update || true
        ;;
    *)
        log_warning "Unknown OS: $OS"
        ;;
esac

log_success "Package lists updated"

#==============================================================================
# Install Python and pip
#==============================================================================
log_info "Installing Python and pip..."

case $OS in
    ubuntu|debian)
        apt-get install -y \
            python3 \
            python3-pip \
            python3-venv \
            software-properties-common \
            curl \
            wget \
            gnupg \
            lsb-release
        ;;
    fedora|rhel|centos)
        dnf install -y \
            python3 \
            python3-pip \
            curl \
            wget \
            gnupg2
        ;;
esac

log_success "Python and pip installed"

#==============================================================================
# Install Ansible
#==============================================================================
log_info "Installing Ansible..."

case $OS in
    ubuntu|debian)
        # Add Ansible PPA for latest version
        add-apt-repository -y ppa:ansible/ansible || true
        apt-get update
        apt-get install -y ansible
        ;;
    fedora|rhel|centos)
        dnf install -y ansible
        ;;
esac

# Verify installation
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -1)
    log_success "Ansible installed: $ANSIBLE_VERSION"
else
    log_error "Ansible installation failed"
    exit 1
fi

# Install Ansible community collections
log_info "Installing Ansible community collections..."
ansible-galaxy collection install community.general
ansible-galaxy collection install community.docker

#==============================================================================
# Install Terraform (The Tricky One!)
#==============================================================================
log_info "Installing Terraform..."

# Determine architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        TERRAFORM_ARCH="amd64"
        ;;
    aarch64|arm64)
        TERRAFORM_ARCH="arm64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

log_info "Architecture: $ARCH (Terraform: $TERRAFORM_ARCH)"

# Method 1: Official HashiCorp repository (RECOMMENDED)
case $OS in
    ubuntu|debian)
        log_info "Adding HashiCorp repository..."
        
        # Add HashiCorp GPG key
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        
        # Add repository
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
        
        # Install
        apt-get update
        apt-get install -y terraform
        ;;
        
    fedora)
        log_info "Adding HashiCorp repository..."
        
        dnf install -y dnf-plugins-core
        dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
        dnf install -y terraform
        ;;
        
    rhel|centos)
        log_info "Adding HashiCorp repository..."
        
        yum install -y yum-utils
        yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        yum install -y terraform
        ;;
esac

# Verify Terraform installation
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform --version | head -1)
    log_success "Terraform installed: $TERRAFORM_VERSION"
else
    log_warning "Repository method failed, trying direct download..."
    
    # Method 2: Direct download (FALLBACK)
    TERRAFORM_VERSION="1.6.6"
    DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip"
    
    log_info "Downloading Terraform ${TERRAFORM_VERSION} for ${TERRAFORM_ARCH}..."
    
    cd /tmp
    wget "$DOWNLOAD_URL" -O terraform.zip
    
    # Install unzip if not present
    case $OS in
        ubuntu|debian)
            apt-get install -y unzip
            ;;
        fedora|rhel|centos)
            dnf install -y unzip
            ;;
    esac
    
    # Extract and install
    unzip -o terraform.zip
    chmod +x terraform
    mv terraform /usr/local/bin/
    
    # Verify
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform --version | head -1)
        log_success "Terraform installed: $TERRAFORM_VERSION"
    else
        log_error "Terraform installation failed"
        log_error "Please install manually: https://www.terraform.io/downloads"
        exit 1
    fi
    
    # Cleanup
    rm -f terraform.zip
fi

#==============================================================================
# Install Python dependencies
#==============================================================================
log_info "Installing Python dependencies..."

pip3 install --upgrade pip

pip3 install \
    pyyaml \
    jsonschema \
    jinja2 \
    requests

log_success "Python dependencies installed"

#==============================================================================
# Install additional useful tools
#==============================================================================
log_info "Installing additional tools..."

case $OS in
    ubuntu|debian)
        apt-get install -y \
            git \
            vim \
            htop \
            net-tools \
            dnsutils \
            iputils-ping \
            curl \
            wget \
            jq \
            yamllint
        ;;
    fedora|rhel|centos)
        dnf install -y \
            git \
            vim \
            htop \
            net-tools \
            bind-utils \
            iputils \
            curl \
            wget \
            jq \
            yamllint
        ;;
esac

log_success "Additional tools installed"

#==============================================================================
# Verify all installations
#==============================================================================
echo ""
log_info "Verifying installations..."
echo ""

ERRORS=0

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓${NC} Python: $PYTHON_VERSION"
else
    echo -e "${RED}✗${NC} Python: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi

# Check pip
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version | cut -d' ' -f2)
    echo -e "${GREEN}✓${NC} pip: $PIP_VERSION"
else
    echo -e "${RED}✗${NC} pip: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi

# Check Ansible
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -1 | cut -d' ' -f2)
    echo -e "${GREEN}✓${NC} Ansible: $ANSIBLE_VERSION"
else
    echo -e "${RED}✗${NC} Ansible: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform --version | head -1 | cut -d' ' -f2)
    echo -e "${GREEN}✓${NC} Terraform: $TERRAFORM_VERSION"
else
    echo -e "${RED}✗${NC} Terraform: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi

# Check Git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    echo -e "${GREEN}✓${NC} Git: $GIT_VERSION"
else
    echo -e "${RED}✗${NC} Git: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [[ $ERRORS -eq 0 ]]; then
    log_success "All prerequisites installed successfully!"
    echo ""
    echo "You can now run:"
    echo "  ./deploy.sh --component ipxe"
    echo ""
else
    log_error "$ERRORS tool(s) failed to install"
    echo ""
    echo "Please check the errors above and install manually if needed."
    exit 1
fi

# Create a verification report
cat > /tmp/prerequisites-report.txt << EOF
Prerequisites Installation Report
==================================
Date: $(date)
OS: $OS $VER
Architecture: $ARCH

Installed Tools:
- Python: $(python3 --version)
- pip: $(pip3 --version | cut -d' ' -f2)
- Ansible: $(ansible --version | head -1)
- Terraform: $(terraform --version | head -1)
- Git: $(git --version)

Installation Complete!
EOF

log_info "Report saved to /tmp/prerequisites-report.txt"

exit 0