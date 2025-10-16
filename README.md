# Esports LAN Infrastructure

A complete, automated infrastructure solution for deploying large-scale esports events (up to 200+ machines) with PXE boot, game caching, and roaming user profiles.

## Overview

This project provides a turnkey solution for esports organizations to deploy scalable, managed gaming infrastructure for tournaments and events. The system includes:

- **iPXE Boot Server**: Network boot clients with fresh Windows 11 images on every restart
- **LANCache**: Local game content caching to reduce internet bandwidth usage
- **File Server**: Roaming profiles for seamless user experience across machines
- **Windows Image Builder**: Automated creation of customized Windows 11 deployment images

## Features

- 🚀 **Fast Deployment**: Players can switch machines in under 5 minutes
- 🔒 **Clean State**: Every boot loads a fresh image, preventing setting persistence
- 💾 **Smart Caching**: Games cached locally on 2TB client drives survive reboots
- 🌐 **Bandwidth Optimization**: LANCache dramatically reduces internet usage during events
- 🎮 **Game Support**: Steam, Epic Games, Riot Games (League, Valorant), and more
- 💬 **Communication**: Pre-installed Discord and TeamSpeak
- 🏫 **Easy Customization**: Simple YAML config for organization branding and settings

## Target Audience

- High school esports organizations
- State/regional tournament organizers
- Schools with permanent esports labs
- Tech-savvy volunteers and IT staff

## Requirements

### Hardware

- **Server**: 1x bare metal server (or multiple for HA)
  - Proxmox VE installed
  - 40TB+ HDD storage
  - 388GB+ RAM recommended
  - 10Gb+ networking recommended
  
- **Network**: 
  - Managed switches (UniFi or similar)
  - Gigabit minimum, 2.5Gb+ preferred
  
- **Clients**: 200x gaming PCs
  - PXE boot capable
  - 2TB local storage (HDD or SSD)
  - 16GB+ RAM

### Software

- Proxmox VE 8.x
- Git
- Visual Studio Code (for configuration)

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/esports-lan-infrastructure.git
   cd esports-lan-infrastructure
   ```

2. **Customize your configuration**
   ```bash
   cp config.example.yaml config.yaml
   # Edit config.yaml with your organization details
   ```

3. **Deploy infrastructure**
   ```bash
   ./deploy.sh
   ```

4. **Build Windows image**
   ```bash
   ./scripts/build-windows-image.sh
   ```

5. **Boot clients via PXE**
   - Configure DHCP to point to your iPXE server
   - Boot client machines from network

## Documentation

- [Getting Started Guide](docs/getting-started.md)
- [Configuration Reference](docs/configuration.md)
- [iPXE Server Setup](docs/ipxe-server.md)
- [LANCache Configuration](docs/lancache.md)
- [File Server Setup](docs/file-server.md)
- [Windows Image Creation](docs/windows-image.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Network Architecture](docs/network-architecture.md)

## Project Structure

```
.
├── config.example.yaml          # Example configuration file
├── deploy.sh                    # Main deployment script
├── ansible/                     # Ansible playbooks for automation
├── terraform/                   # Terraform for Proxmox VM provisioning
├── ipxe/                        # iPXE boot server configuration
├── lancache/                    # LANCache server setup
├── fileserver/                  # File server and roaming profiles
├── windows-image/               # Windows 11 image builder
├── scripts/                     # Utility scripts
├── docs/                        # Documentation
└── .github/workflows/           # CI/CD pipelines
```

## Customization

All customization is done through `config.yaml`:

```yaml
organization:
  name: "Your School Esports"
  short_name: "YSE"
  
network:
  ipxe_server: "192.168.1.10"
  lancache_server: "192.168.1.11"
  file_server: "192.168.1.12"
  dhcp_range_start: "192.168.1.100"
  dhcp_range_end: "192.168.1.254"
  
games:
  - fortnite
  - rocket_league
  - valorant
  - league_of_legends
  - overwatch2
  - marvel_rivals
```

See [Configuration Reference](docs/configuration.md) for all options.

## Development Phases

- [x] Phase 1: Repository structure and CI/CD foundation
- [ ] Phase 2: iPXE boot server
- [ ] Phase 3: LANCache server
- [ ] Phase 4: File server and roaming profiles
- [ ] Phase 5: Windows 11 image builder
- [ ] Phase 6: Integration and testing

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) before submitting pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details

## Support

- GitHub Issues: Report bugs and request features
- Documentation: Check our comprehensive docs
- Community: Join our Discord server (link TBD)

## Acknowledgments

- LANCache project for game caching solution
- iPXE project for network boot infrastructure
- High school esports community for requirements and testing

---

**Status**: 🚧 In Development - Phase 1 Complete

**Tested With**: Proxmox VE 8.x, Windows 11 23H2, UniFi switching infrastructure