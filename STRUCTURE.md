# Repository Directory Structure

This document outlines the complete directory structure for the High School Esports LAN Infrastructure project.

```
esports-lan-infrastructure/
│
├── .github/
│   ├── workflows/
│   │   ├── validate.yml                 # CI/CD validation pipeline
│   │   ├── test.yml                     # Integration tests (Phase 6)
│   │   └── release.yml                  # Release automation (Phase 6)
│   │
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   │
│   └── markdown-link-check-config.json
│
├── ansible/                              # Ansible automation (Phase 2-6)
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.example
│   │   └── group_vars/
│   │       └── all.yml
│   │
│   ├── playbooks/
│   │   ├── deploy_all.yml               # Master deployment playbook
│   │   ├── deploy_ipxe.yml              # Phase 2
│   │   ├── deploy_lancache.yml          # Phase 3
│   │   ├── deploy_fileserver.yml        # Phase 4
│   │   └── deploy_windows_builder.yml   # Phase 5
│   │
│   ├── roles/
│   │   ├── common/                      # Common configuration for all VMs
│   │   ├── ipxe/                        # iPXE server role
│   │   ├── lancache/                    # LANCache server role
│   │   ├── fileserver/                  # File server role
│   │   └── windows_builder/             # Windows image builder role
│   │
│   └── README.md
│
├── terraform/                            # Infrastructure as Code (Phase 2-6)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── versions.tf
│   │
│   ├── modules/
│   │   ├── proxmox_vm/                  # Reusable VM module
│   │   ├── network/                     # Network configuration
│   │   └── storage/                     # Storage configuration
│   │
│   └── README.md
│
├── ipxe/                                 # iPXE Boot Server (Phase 2)
│   ├── config/
│   │   ├── dhcpd.conf.j2               # DHCP server template
│   │   └── boot.ipxe.j2                # iPXE boot menu template
│   │
│   ├── scripts/
│   │   ├── setup.sh                    # Setup script for iPXE server
│   │   └── test_pxe.sh                 # Test PXE boot functionality
│   │
│   ├── files/
│   │   └── ipxe.efi                    # iPXE bootloader
│   │
│   └── README.md
│
├── lancache/                            # LANCache Server (Phase 3)
│   ├── config/
│   │   ├── docker-compose.yml          # LANCache containers
│   │   ├── lancache.conf.j2            # Nginx configuration template
│   │   └── cache-domains.json          # Cached domains configuration
│   │
│   ├── scripts/
│   │   ├── setup.sh                    # LANCache setup script
│   │   ├── prefill.sh                  # Pre-download games script
│   │   └── monitor.sh                  # Cache monitoring script
│   │
│   └── README.md
│
├── fileserver/                          # File Server (Phase 4)
│   ├── config/
│   │   ├── smb.conf.j2                 # Samba configuration
│   │   ├── nfs-exports.j2              # NFS exports
│   │   └── user_template/              # Default user profile template
│   │
│   ├── scripts/
│   │   ├── setup.sh                    # File server setup
│   │   ├── create_shares.sh            # Create SMB shares
│   │   └── manage_profiles.sh          # Profile management utilities
│   │
│   └── README.md
│
├── windows-image/                       # Windows Image Builder (Phase 5)
│   ├── config/
│   │   ├── autounattend.xml.j2         # Windows unattended installation
│   │   ├── optimize.ps1                # Windows optimization script
│   │   └── install_apps.ps1            # Application installation script
│   │
│   ├── scripts/
│   │   ├── build_image.sh              # Main image build script
│   │   ├── setup_builder_vm.sh         # Setup builder VM
│   │   ├── install_game_clients.ps1    # Install game launchers
│   │   ├── configure_local_cache.ps1   # Configure local disk caching
│   │   └── sysprep.ps1                 # Sysprep and capture image
│   │
│   ├── drivers/
│   │   └── .gitkeep                    # Place network/storage drivers here
│   │
│   ├── installers/
│   │   ├── download.sh                 # Download game clients
│   │   └── .gitkeep
│   │
│   └── README.md
│
├── scripts/                             # Utility Scripts
│   ├── deploy.sh                       # Main deployment orchestrator
│   ├── validate_config.py              # Configuration validator
│   ├── preflight_check.sh              # Pre-deployment checks
│   ├── backup.sh                       # Backup utility
│   ├── restore.sh                      # Restore utility
│   ├── update.sh                       # Update infrastructure
│   └── troubleshoot.sh                 # Troubleshooting helper
│
├── docs/                                # Documentation
│   ├── getting-started.md              # Quick start guide
│   ├── configuration.md                # Configuration reference
│   ├── network-architecture.md         # Network design
│   │
│   ├── phase2-ipxe/
│   │   ├── setup.md
│   │   ├── troubleshooting.md
│   │   └── network-boot-guide.md
│   │
│   ├── phase3-lancache/
│   │   ├── setup.md
│   │   ├── game-support.md
│   │   ├── prefill-guide.md
│   │   └── monitoring.md
│   │
│   ├── phase4-fileserver/
│   │   ├── setup.md
│   │   ├── roaming-profiles.md
│   │   ├── folder-redirection.md
│   │   └── performance-tuning.md
│   │
│   ├── phase5-windows/
│   │   ├── image-creation.md
│   │   ├── customization.md
│   │   ├── driver-injection.md
│   │   └── application-installation.md
│   │
│   ├── phase6-integration/
│   │   ├── end-to-end-testing.md
│   │   ├── performance-optimization.md
│   │   └── deployment-checklist.md
│   │
│   ├── troubleshooting.md              # Common issues and solutions
│   ├── faq.md                          # Frequently asked questions
│   ├── hardware-requirements.md        # Detailed hardware specs
│   ├── network-design.md               # Network topology
│   └── best-practices.md               # Deployment best practices
│
├── monitoring/                          # Monitoring and Logging (Phase 6)
│   ├── prometheus/
│   │   └── prometheus.yml
│   │
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── network_overview.json
│   │   │   ├── lancache_stats.json
│   │   │   └── client_health.json
│   │   └── provisioning/
│   │
│   └── README.md
│
├── testing/                             # Testing Framework (Phase 6)
│   ├── integration/
│   │   ├── test_pxe_boot.sh
│   │   ├── test_lancache.sh
│   │   ├── test_profiles.sh
│   │   └── test_end_to_end.sh
│   │
│   ├── unit/
│   │   └── test_config_validator.py
│   │
│   └── load/
│       └── simulate_200_clients.sh
│
├── branding/                            # Organization Branding (Optional)
│   ├── .gitkeep
│   ├── wallpaper.example.jpg
│   ├── lockscreen.example.jpg
│   └── README.md
│
├── examples/                            # Example Configurations
│   ├── small_deployment/               # 50 client setup
│   │   └── config.yaml
│   │
│   ├── medium_deployment/              # 100 client setup
│   │   └── config.yaml
│   │
│   ├── large_deployment/               # 200+ client setup
│   │   └── config.yaml
│   │
│   └── multi_server/                   # HA multi-server setup
│       └── config.yaml
│
├── tools/                               # Additional Tools
│   ├── network_calculator.py           # Calculate IP ranges
│   ├── resource_estimator.py           # Estimate resource needs
│   └── compatibility_checker.sh        # Check hardware compatibility
│
├── config.example.yaml                  # Example configuration file
├── .gitignore                          # Git ignore rules
├── README.md                           # Main documentation
├── CONTRIBUTING.md                     # Contribution guidelines
├── LICENSE                             # MIT License
├── CHANGELOG.md                        # Version history
└── deploy.sh                           # Main deployment script
```

## Directory Purposes

### Core Configuration
- **config.example.yaml**: Template configuration file that users copy and customize
- **deploy.sh**: Main entry point for deployment

### Infrastructure as Code
- **terraform/**: Provisions VMs on Proxmox
- **ansible/**: Configures and manages all services

### Service-Specific Directories
- **ipxe/**: Network boot server configuration (Phase 2)
- **lancache/**: Game content caching server (Phase 3)
- **fileserver/**: User profile and file storage (Phase 4)
- **windows-image/**: Windows 11 image creation (Phase 5)

### Automation & Testing
- **scripts/**: Utility scripts for deployment, backup, and management
- **testing/**: Automated testing framework
- **monitoring/**: Performance monitoring and dashboards

### Documentation
- **docs/**: Comprehensive documentation organized by phase
- **examples/**: Real-world configuration examples

### Development
- **.github/**: CI/CD workflows and issue templates
- **tools/**: Helper utilities for planning and troubleshooting

## File Naming Conventions

### Scripts
- Use lowercase with underscores: `setup_server.sh`
- Make executable: `chmod +x script_name.sh`
- Include shebang: `#!/bin/bash`

### Configuration Files
- Use `.j2` extension for Jinja2 templates
- Use descriptive names: `smb.conf.j2` not `config.j2`

### Documentation
- Use lowercase with hyphens: `getting-started.md`
- Include README.md in each major directory

## What Gets Committed

### DO Commit:
- Example configurations
- Templates
- Scripts and automation
- Documentation
- Test files

### DO NOT Commit:
- `config.yaml` (contains sensitive data)
- Private keys, certificates
- ISOs, WIM files, large binaries
- Downloaded game installers
- User data or profiles
- Secrets or passwords

## Next Steps

This structure will be populated incrementally:
1. **Phase 1** (Current): Core structure, config system, CI/CD
2. **Phase 2**: iPXE server implementation
3. **Phase 3**: LANCache implementation
4. **Phase 4**: File server implementation
5. **Phase 5**: Windows image builder
6. **Phase 6**: Integration and testing