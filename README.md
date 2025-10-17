# Esports LAN Infrastructure

A complete, automated infrastructure solution for deploying large-scale esports events (up to 200+ machines) with PXE boot, game caching, and roaming user profiles.

(Buy Me a Coffee)[https://buymeacoffee.com/datrix838]

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

## 🔒 Security

This is a public repository containing infrastructure-as-code.

**NEVER commit**:
- config.yaml (your actual configuration)
- SSH keys, certificates, passwords
- Terraform state files
- Ansible inventory with real IPs

**Always use**:
- config.example.yaml as a template
- Ansible Vault for sensitive data
- GitHub Secrets for CI/CD
- Environment variables for credentials

See [SECURITY.md](SECURITY.md) for full details.

**Reporting Security Issues**: security@idahoesports.gg

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
- [x] Phase 2: iPXE boot server
- [x] Phase 3: LANCache server
- [x] Phase 4: File server and roaming profiles
- [x] Phase 5: Windows 11 image builder
- [x] Phase 6: Integration and testing

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

# Bonus Features

Additional features beyond the core 5 phases to enhance tournament operations.

## ✅ Feature 1: Custom Machine Naming (MAC Address Mapping)

### What It Does

Assign fun, memorable names to machines instead of generic ESPORTS-001, ESPORTS-002.

### Themes Available

- **Star Trek**: Enterprise, Voyager, Defiant, Discovery (50 ships)
- **Star Wars**: Millennium Falcon, X-Wing, Star Destroyer (50 ships)
- **Lord of the Rings**: Rivendell, Gondor, Rohan, Shire (50 locations)
- **Harry Potter**: Hogwarts, Gryffindor, Hogsmeade (50 locations)

### Configuration

```yaml
# config/mac-addresses.yaml
mac_mappings:
  "aa:bb:cc:dd:ee:ff": "ENTERPRISE"
  "aa:bb:cc:dd:ee:01": "VOYAGER"

themes:
  star-trek:
    names:
      - ENTERPRISE
      - VOYAGER
      - DEFIANT
```

### Benefits

- **Easier troubleshooting**: "ENTERPRISE is having issues" vs "machine 47"
- **More fun**: Players remember "I was on MILLENNIUM-FALCON!"
- **Staff efficiency**: Quick machine identification

### Implementation

Files: `config/mac-addresses.yaml`, integration with dnsmasq/DHCP

---

## ✅ Feature 2: Remote Machine Management

### What It Does

Remotely control all machines, clusters, or individual machines from one command.

### Actions Available

- **shutdown** - Graceful shutdown
- **reboot** - Restart machines
- **lock** - Lock user sessions
- **unlock** - Unlock sessions
- **wol** - Wake-on-LAN (power on)
- **disable** - Disable network (isolate machine)
- **enable** - Re-enable network

### Usage Examples

```bash
# Shut down all machines at end of day
./scripts/manage_machines.sh --action shutdown --target all

# Reboot a specific machine
./scripts/manage_machines.sh --action reboot --target machine ENTERPRISE

# Lock a cluster during break
./scripts/manage_machines.sh --action lock --target cluster gryffindor

# Wake machines in IP range
./scripts/manage_machines.sh --action wol --target range 100-120

# Isolate problematic machine
./scripts/manage_machines.sh --action disable --target ip 192.168.1.105
```

### Cluster Management

Define clusters in `config/clusters.yaml`:
```yaml
gryffindor:
  - 192.168.1.100
  - 192.168.1.101
  - 192.168.1.102

slytherin:
  - 192.168.1.110
  - 192.168.1.111
```

### Benefits

- **Mass operations**: Shut down 200 machines in minutes
- **Emergency control**: Quickly isolate problematic machines
- **Scheduled operations**: Script automatic shutdowns
- **Event management**: Lock machines during breaks

### Safety Features

- Confirmation prompts (can be skipped with --confirm)
- Dry-run mode to preview actions
- Only affects online machines
- Logs all actions

### Implementation

File: `scripts/manage_machines.sh`

---

## ✅ Feature 3: Self-Service Registration

### What It Does

Web-based registration system where players create their own accounts at the event.

### Features

- **Beautiful web interface**: Modern, responsive design
- **Real-time validation**: Username/password requirements
- **Duplicate prevention**: Checks if username exists
- **Live counter**: Shows how many players registered
- **Mobile friendly**: Works on laptops, tablets, phones

### Deployment Options

**Option A: Dedicated Registration Laptop**
```bash
# On a laptop with wireless connection
cd registration
python3 webapp.py

# Access at: http://laptop-ip:5000
```

**Option B: On Every Gaming PC**
```bash
# Players can self-register before logging in
# Add to Windows startup
```

**Option C: Registration Kiosk**
```bash
# Dedicated touchscreen kiosk at entrance
# Fullscreen browser pointing to registration page
```

### Registration Flow

1. Player opens registration page
2. Enters username, password, email
3. Optionally enters team/school
4. Clicks "Create Account"
5. Account created on file server
6. Player gets confirmation with credentials
7. Can immediately login at any PC

### Requirements Enforced

- Username: 3-15 characters, alphanumeric only
- Password: Minimum 8 characters
- Email: Valid email format
- Duplicate prevention

### Benefits

- **Reduces staff workload**: No manual account creation
- **Faster registration**: Players create own accounts
- **Self-service**: Available 24/7 during event
- **Scalable**: Handles hundreds of registrations

### Implementation

Files: `registration/webapp.py` (Flask web app)

---

## ✅ Feature 4: Custom Wallpapers & Screensavers

### What It Does

Apply organization-specific branding to all machines automatically.

### Customization Options

- **Desktop wallpaper**: Organization logo/design
- **Lock screen**: Tournament branding
- **Screensaver**: Custom slideshow or logo
- **Login screen**: Custom background

### How to Use

**Add Your Branding:**
```bash
# Add files to branding folder
cp your-wallpaper.jpg branding/wallpaper.jpg
cp your-lockscreen.jpg branding/lockscreen.jpg
cp your-logo.png branding/logo.png
```

**Enable in Config:**
```yaml
branding:
  wallpaper:
    enabled: true
    path: "branding/wallpaper.jpg"
  
  lock_screen:
    enabled: true
    path: "branding/lockscreen.jpg"
```

**Rebuild Windows Image:**
```bash
# Branding is applied during image build
./scripts/build_windows_image.sh
```

### What Gets Applied

- Desktop wallpaper on all user profiles
- Lock screen background
- Login screen background (optional)
- Organization logo in taskbar (optional)

### Benefits

- **Professional appearance**: Branded tournament setup
- **Sponsor visibility**: Display sponsor logos
- **School pride**: Show school colors/mascot
- **Consistent look**: All 200 machines identical

### Implementation

Integrated into `windows-image/config/optimize.ps1` and image build process

---

## ✅ Feature 5: Gaming Kiosk Shell (ADVANCED)

### What It Does

Replaces Windows shell with a custom gaming launcher, preventing users from accessing Windows directly.

### Features

- **Clean interface**: Big buttons, game icons, easy navigation
- **Game launchers**: Steam, Epic, Riot, Battle.net integration
- **Utilities**: Discord, TeamSpeak, audio, Bluetooth
- **Locked down**: Users can't access Windows desktop
- **Beautiful design**: Modern, gradient UI with animations
- **Admin access**: Password-protected settings

### What It Looks Like

```
┌─────────────────────────────────────────────────┐
│  🎮 High School Esports            12:45 PM 🚪  │
│  Welcome, player123!                             │
├─────────────────────────────────────────────────┤
│                                                  │
│  🎮 GAMES                                        │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐  │
│  │   🎮   │ │   🚗   │ │   🎯   │ │   ⚔️   │  │
│  │Fortnite│ │Rocket  │ │Valorant│ │League  │  │
│  │via Epic│ │League  │ │via Riot│ │  LoL   │  │
│  └────────┘ └────────┘ └────────┘ └────────┘  │
│                                                  │
│  🛠️ UTILITIES                                   │
│  ┌────────┐ ┌────────┐ ┌────────┐              │
│  │   💬   │ │   🎙️   │ │   🔊   │              │
│  │Discord │ │TeamSpeak│ │ Audio  │              │
│  └────────┘ └────────┘ └────────┘              │
│                                                  │
├─────────────────────────────────────────────────┤
│  ALT+F4 to exit         ❓ Help    ⚙️ Settings │
└─────────────────────────────────────────────────┘
```

### Benefits

- **Simplified interface**: No Windows complexity
- **Prevents mistakes**: Can't accidentally break things
- **Faster launching**: Direct access to games
- **Better focus**: No distractions
- **Tournament mode**: Controlled environment

### Games Included

- Fortnite (via Epic)
- Rocket League (via Epic)
- Valorant (via Riot)
- League of Legends (via Riot)
- Overwatch 2 (via Battle.net)
- Steam Library

### Utilities Included

- Discord
- TeamSpeak
- Audio Settings (Windows)
- Bluetooth Settings (Windows)

### Admin Access

- Password-protected settings button
- Opens Windows Explorer for troubleshooting
- Default password: `admin123` (change in code)

### How to Enable

**Option 1: Replace Windows Shell (Full Lockdown)**
```powershell
# Set as Windows shell (runs instead of Explorer)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
    -Name "Shell" `
    -Value "powershell.exe -ExecutionPolicy Bypass -File C:\Kiosk\gaming-launcher.ps1"
```

**Option 2: Auto-start Application (Partial Lockdown)**
```powershell
# Starts with Windows but can be closed
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "GamingLauncher" `
    -Value "powershell.exe -WindowStyle Maximized -File C:\Kiosk\gaming-launcher.ps1"
```

**Option 3: Manual Launch (Testing)**
```powershell
# Just run the script
powershell.exe -ExecutionPolicy Bypass -File kiosk\gaming-launcher.ps1
```

### Customization

Edit `kiosk/gaming-launcher.ps1`:

```powershell
# Add more games
$GAMES = @(
    @{
        Name = "Your Game"
        Icon = "🎮"
        Launcher = "Steam"
        Path = "steam://rungameid/123456"
        Color = "#FF0000"
    }
)

# Change colors
$CONFIG = @{
    BackgroundColor = "#1a1a2e"
    AccentColor = "#0f3460"
    TextColor = "#eaeaea"
}
```

### Security Notes

- **Keyboard shortcuts disabled**: Ctrl+Alt+Del caught and blocked
- **Task Manager access**: Blocked (can be overridden by admin password)
- **Alt+F4 still works**: Allows exiting if needed
- **Admin override**: Settings button with password access

### Implementation

File: `kiosk/gaming-launcher.ps1` (PowerShell + WPF)

---

## 🎯 Implementation Status

| Feature | Status | Complexity | Time to Deploy |
|---------|--------|------------|----------------|
| Custom Machine Names | ✅ Complete | Easy | 30 min |
| Remote Management | ✅ Complete | Medium | 1 hour |
| Self-Service Registration | ✅ Complete | Medium | 1 hour |
| Custom Wallpapers | ✅ Complete | Easy | 15 min |
| Gaming Kiosk Shell | ✅ Complete | Advanced | 2-3 hours |

## 📦 Installation Guide

### Feature 1: Custom Machine Names

1. **Edit MAC address file:**

```bash
cp config/mac-addresses.example.yaml config/mac-addresses.yaml
nano config/mac-addresses.yaml
# Add your MAC addresses
```

2. **Choose theme:**

```yaml
naming:
  use_themed_names: true
  default_theme: "star-trek"
```

3. **Update DHCP:**

```bash
# Regenerates dnsmasq config with custom names
./deploy.sh --component ipxe
```

### Feature 2: Remote Management

1. **Ensure SSH access to machines** (or use WinRM)

2. **Create cluster definitions:**

```bash
nano config/clusters.yaml
```

3. **Test on one machine:**

```bash
./scripts/manage_machines.sh --action shutdown --target ip 192.168.1.100 --dry-run
```

4. **Use in production:**

```bash
./scripts/manage_machines.sh --action shutdown --target all
```

### Feature 3: Self-Service Registration

1. **Install Flask:**

```bash
pip3 install flask pyyaml
```

2. **Configure SSH access to file server:**

```bash
ssh-keygen
ssh-copy-id ansible@192.168.1.12
```

3. **Start registration server:**

```bash
cd registration
python3 webapp.py
```

4. **Access from any device:**

```
http://laptop-ip:5000
```

### Feature 4: Custom Wallpapers

1. **Add your images:**

```bash
mkdir -p branding
cp your-wallpaper.jpg branding/wallpaper.jpg
```

2. **Enable in config:**

```yaml
branding:
  wallpaper:
    enabled: true
```

3. **Rebuild Windows image:**

```bash
./scripts/build_windows_image.sh
```

### Feature 5: Gaming Kiosk Shell

1. **Copy script to Windows image:**

```bash
# During image build, script is copied to C:\Kiosk\
```

2. **Test manually first:**

```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\Kiosk\gaming-launcher.ps1
```

3. **Enable as Windows shell (optional):**

```powershell
# Add to Windows image build scripts
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
    -Name "Shell" -Value "powershell.exe -ExecutionPolicy Bypass -File C:\Kiosk\gaming-launcher.ps1"
```

4. **Or add to startup:**

```powershell
# Less restrictive option
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "GamingLauncher" `
    -Value "powershell.exe -WindowStyle Maximized -File C:\Kiosk\gaming-launcher.ps1"
```

## 🎓 Usage Scenarios

### Scenario 1: Professional Tournament

```bash
# Use Star Trek names for style
# Enable kiosk shell for controlled environment
# Self-service registration at entrance
# Remote management for mass operations
```

### Scenario 2: School Lab (Permanent)

```bash
# Use Harry Potter names (house pride!)
# Custom school wallpapers
# Kiosk shell prevents student access to Windows
# Remote shutdown at end of day
```

### Scenario 3: Multi-Day Event

```bash
# Use Star Wars names (fan favorite!)
# Self-service registration day 1
# Remote lock machines during lunch
# Wake-on-LAN to power on next morning
```

## 📊 Complexity Analysis

### Easy to Implement NOW ✅

1. **Custom Machine Names** - Just config file changes
2. **Custom Wallpapers** - Add images, rebuild
3. **Remote Management** - Script is ready to use

### Moderate - Test First ⚠️

4. **Self-Service Registration** - Requires web server setup
5. **Gaming Kiosk Shell** - Needs testing with your games

### Notes on Kiosk Shell

- Most complex feature
- Test thoroughly before deploying to 200 machines
- Consider starting with auto-start instead of shell replacement
- Have admin password ready for troubleshooting
- May need adjustments for your specific games

## 🚀 Recommended Deployment Order

1. **Phase 1**: Deploy custom machine names (easy win!)
2. **Phase 2**: Set up self-service registration (high value)
3. **Phase 3**: Add custom wallpapers (looks professional)
4. **Phase 4**: Test remote management on 5 machines
5. **Phase 5**: Test kiosk shell on 1 machine, then expand

## 💡 Pro Tips

### Machine Names

- Use theme voting with students (they love this!)
- Print reference sheet: "PC 1 = ENTERPRISE"
- Staff learns names quickly

### Remote Management

- Always test with --dry-run first
- Create cluster aliases for common groups
- Schedule automatic shutdowns
- Use WOL for morning power-on

### Registration

- Set up iPad at entrance for registrations
- Pre-create admin accounts manually
- Monitor registration.log for issues
- Have staff override capability

### Wallpapers

- High resolution (1920x1080 minimum)
- School colors work great
- Sponsor logos = funding!
- Seasonal themes are fun

### Kiosk Shell

- Start with auto-start, not shell replacement
- Test with ALL games first
- Document admin password clearly
- Have escape mechanism (Alt+F4)
- Train staff on admin access

## 🎉 Final Thoughts

These bonus features transform the system from "functional" to "amazing":

- **Custom names** = Personality and easier troubleshooting
- **Remote management** = Staff efficiency and control
- **Self-service registration** = Scalability and speed
- **Custom branding** = Professional appearance
- **Gaming kiosk** = Simplified, controlled environment

**Total additional work: 4-8 hours** to implement everything
**Value added: Immeasurable** in terms of operations and user experience!

---

**Questions or Issues?**

- Test each feature independently
- Don't enable all at once
- Keep backups of working configurations
- Document your customizations
