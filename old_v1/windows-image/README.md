# Windows Image Builder

The Windows Image Builder creates a customized Windows 11 installation that includes all game clients, optimizations, and configurations for esports tournaments. This image is deployed via PXE boot to all client machines.

## What This Creates

A fully configured Windows 11 image with:
- ✅ Game clients pre-installed (Steam, Epic, Riot)
- ✅ Communication apps (Discord, TeamSpeak)
- ✅ Roaming profiles configured
- ✅ Folder redirection to local G: drive
- ✅ Windows optimizations (disabled telemetry, etc.)
- ✅ LANCache DNS pre-configured
- ✅ Automatic profile mounting
- ✅ Games stored on local 2TB drive

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Windows Image Builder VM (Temporary)                     │
│                                                           │
│ 1. Install Windows 11 (unattended)                       │
│ 2. Windows Updates                                       │
│ 3. Install game clients                                  │
│ 4. Install communication apps                            │
│ 5. Apply optimizations                                   │
│ 6. Configure roaming profiles                            │
│ 7. Configure folder redirection                          │
│ 8. Run Sysprep                                           │
│ 9. Capture to WIM file                                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ boot.wim (Windows PE Boot Image)                         │
│ - Contains Windows installer                             │
│ - Includes network drivers                               │
│ - Served via iPXE server                                 │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Client Machines Boot Process                             │
│ 1. PXE boot → iPXE menu                                  │
│ 2. Load boot.wim from network                            │
│ 3. Apply Windows image to C:                             │
│ 4. First boot: Configure local G: drive                  │
│ 5. Mount network profile                                 │
│ 6. User logs in → Settings load                          │
└─────────────────────────────────────────────────────────┘
```

## Image Contents

### Pre-installed Software

**Game Clients:**
- Steam
- Epic Games Launcher
- Riot Client (Valorant, LoL)
- Battle.net (optional)

**Communication:**
- Discord
- TeamSpeak 3
- TeamSpeak 6 (new version)

**Utilities:**
- 7-Zip
- Chrome
- VLC Media Player
- GPU drivers (generic, updated per machine)

**Not Included (installed by game clients):**
- Actual games (downloaded via LANCache)
- Game updates (via LANCache)
- DLC/addons (via LANCache)

### Optimizations Applied

**Performance:**
- High performance power plan
- Gaming mode enabled
- Unnecessary services disabled
- Visual effects optimized

**Privacy/Telemetry:**
- Cortana disabled
- Windows telemetry minimized
- OneDrive disabled (using local storage)
- Windows Search optimized

**Network:**
- DNS set to LANCache (192.168.1.11)
- Network discovery enabled
- SMB signing enabled

**Storage:**
- C: drive for OS (250GB partition)
- G: drive for games/data (1.7TB)
- Automatic game folder creation

## Directory Structure

```
windows-image/
├── config/
│   ├── autounattend.xml.j2       # Unattended Windows install
│   ├── optimize.ps1              # Windows optimizations
│   ├── install_apps.ps1          # Install game clients
│   ├── configure_profiles.ps1    # Roaming profile setup
│   └── folder_redirection.xml    # GPO for folder redirect
│
├── scripts/
│   ├── build_image.sh            # Main orchestration script
│   ├── setup_builder_vm.sh       # Create builder VM
│   ├── download_windows.sh       # Get Windows ISO
│   ├── install_game_clients.ps1  # Game client installers
│   ├── configure_local_cache.ps1 # Setup G: drive
│   ├── sysprep.ps1               # Generalize image
│   └── capture_image.ps1         # Create WIM file
│
├── drivers/
│   └── .gitkeep                  # Network/storage drivers
│
├── installers/
│   ├── download.sh               # Download installers
│   └── .gitkeep
│
└── README.md                     # This file
```

## Building the Image

### Prerequisites

- Windows 11 ISO (download legally from Microsoft)
- Product key (or use evaluation)
- 200GB free space for temporary files
- Time: 2-4 hours for full build

### Automated Build

```bash
# From project root
./scripts/build_windows_image.sh
```

This script:
1. Downloads Windows 11 ISO (if needed)
2. Creates builder VM in Proxmox
3. Installs Windows unattended
4. Runs all configuration scripts
5. Captures image to WIM
6. Copies to iPXE server
7. Cleans up builder VM

### Manual Build

If you prefer step-by-step control:

```bash
# 1. Download Windows ISO
cd windows-image/scripts
./download_windows.sh

# 2. Create builder VM
./setup_builder_vm.sh

# 3. Install Windows (automatic via autounattend.xml)
# Wait 30-45 minutes

# 4. Run configuration scripts (on builder VM)
.\optimize.ps1
.\install_apps.ps1
.\configure_profiles.ps1
.\configure_local_cache.ps1

# 5. Sysprep and capture
.\sysprep.ps1
.\capture_image.ps1

# 6. Copy image to iPXE server
# From host:
scp install.wim ansible@192.168.1.10:/srv/images/windows11/
```

## Configuration Files

### autounattend.xml

Automates Windows installation:
- Partitioning (C: 250GB, G: remaining)
- Locale and timezone
- User account creation
- Network configuration
- Auto-login for setup
- Product key (if provided)

### optimize.ps1

Windows optimizations:
- Disable Cortana
- Disable telemetry
- Disable Windows Search indexing (optional)
- Enable gaming mode
- Set high performance power plan
- Disable unnecessary services
- Registry tweaks

### install_apps.ps1

Installs software using Chocolatey or direct downloads:
- Steam
- Epic Games Launcher
- Riot Client
- Discord
- TeamSpeak 3 and 6
- Chrome
- 7-Zip
- VLC

### configure_profiles.ps1

Sets up roaming profiles:
- Registry keys for profile path
- Folder redirection configuration
- Network drive mapping
- Auto-mount file server shares

### configure_local_cache.ps1

Configures G: drive for games:
- Create folder structure
- Set game install paths
- Configure Steam library
- Configure Epic games folder
- Symlinks for game saves

## Image Deployment

Once built, the image is deployed via iPXE:

1. Client boots via PXE
2. iPXE menu loads
3. User selects "Boot Windows 11"
4. wimboot loads boot.wim
5. Windows PE applies install.wim to C:
6. First boot: OOBE runs (minimal)
7. User logs in
8. Profile loads from file server
9. Ready to play!

## Customization

### Add Custom Software

Edit `install_apps.ps1`:
```powershell
# Add your software
choco install your-software -y
```

### Change Optimizations

Edit `optimize.ps1`:
```powershell
# Comment out unwanted optimizations
# Add your own tweaks
```

### Custom Wallpaper

Place in `windows-image/branding/`:
```bash
cp your-wallpaper.jpg windows-image/branding/wallpaper.jpg
```

It will be applied automatically.

### Pre-install Games

**Not recommended!** Games are huge (50GB+) and would make the image massive.

Instead:
1. Let LANCache cache games
2. First client downloads (cached)
3. Other clients get from cache (fast)

But if you really want to:
```powershell
# In install_apps.ps1
# Install Steam
# Login to Steam (use temporary account)
# Download game
# Image will be HUGE!
```

## Image Maintenance

### Update Image

Re-run the build process:
```bash
./scripts/build_windows_image.sh --update
```

This:
- Keeps existing image as backup
- Builds new image with updates
- Deploys new image
- Old image archived

### Add Software

Mount existing image, add software, recapture:
```bash
# Mount WIM
dism /Mount-Wim /WimFile:install.wim /Index:1 /MountDir:C:\mount

# Make changes
# (Install software, copy files, etc.)

# Save changes
dism /Unmount-Wim /MountDir:C:\mount /Commit
```

### Windows Updates

Build includes latest updates at build time. To update:
```bash
# Rebuild image (recommended)
./scripts/build_windows_image.sh

# Or update mounted image
dism /Mount-Wim /WimFile:install.wim /Index:1 /MountDir:C:\mount
dism /Image:C:\mount /Cleanup-Image /StartComponentCleanup
dism /Unmount-Wim /MountDir:C:\mount /Commit
```

## Testing the Image

### Test in VM

1. Create test VM in Proxmox
2. Configure PXE boot
3. Boot from network
4. Verify image loads
5. Check all software installed
6. Test roaming profile
7. Test game installation

### Test on Physical Machine

1. One machine first (not 200!)
2. PXE boot
3. Time the process (should be 5-10 min)
4. Verify all features
5. Install a game via LANCache
6. Test profile switching

### Checklist

- [ ] Windows boots successfully
- [ ] All game clients present
- [ ] Discord/TeamSpeak installed
- [ ] Roaming profile loads
- [ ] G: drive configured
- [ ] LANCache DNS working
- [ ] Steam can download games
- [ ] Epic can download games
- [ ] Profile persists after reboot
- [ ] Settings survive machine switch

## Troubleshooting

### Build Fails

**Check logs:**
```bash
# On builder VM
C:\Windows\Panther\unattend.xml
C:\Windows\Panther\setupact.log
```

**Common issues:**
- Product key invalid
- ISO corrupted
- Not enough disk space
- Network timeout

### Image Won't Boot

**Check boot files:**
```bash
# On iPXE server
ls -la /srv/images/windows11/
# Should have:
# - boot.wim
# - install.wim
# - bootmgr.exe
# - BCD file
```

**Check iPXE config:**
```bash
# Verify boot.ipxe has correct paths
cat /srv/tftp/boot.ipxe
```

### Profile Won't Load

**Check network:**
```bash
# From client (after boot)
ping 192.168.1.12  # File server
net use * \\192.168.1.12\profiles password /user:player1
```

**Check registry:**
```powershell
# Profile path should be set
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
```

### Games Won't Download

**Check DNS:**
```powershell
nslookup steamcdn.com
# Should return 192.168.1.11 (LANCache)
```

**Check game client:**
- Steam: Settings → Downloads → Steam Library Folders
- Should show G:\SteamLibrary

## Performance

### Image Size
- **Base Windows 11**: ~15GB
- **With all software**: ~20GB
- **Compressed WIM**: ~12GB
- **Network transfer**: 5-10 minutes @ 10Gbps

### First Boot
- **Image application**: 5-10 minutes
- **First boot OOBE**: 2-3 minutes
- **Profile load**: 30-60 seconds
- **Total**: ~10-15 minutes

### Subsequent Boots
- **PXE to login**: 5-8 minutes
- **Profile load**: 30 seconds
- **Total**: ~6-9 minutes

## Best Practices

### Before Building
- Download Windows ISO ahead of time
- Have all installers ready
- Test scripts in a VM first
- Plan for 4-6 hours total time

### During Building
- Don't interrupt the process
- Monitor for errors
- Keep logs
- Test immediately after

### After Building
- Test on one machine first
- Keep old image as backup
- Document any issues
- Brief staff on new features

## Security Considerations

### Sysprep Generalization
- Removes computer-specific data
- Generates new SIDs
- Clears event logs
- Resets activation

### No Credentials in Image
- No passwords stored
- No auto-login (except during build)
- Users authenticate to file server
- Admin account has strong password

### Updates
- Build includes latest patches
- Disable automatic updates during events
- Schedule updates between events
- Test updates before deploying

## Integration

### With iPXE (Phase 2)
- boot.wim served via TFTP/HTTP
- install.wim via HTTP (faster)
- Boot menu configured
- Automatic deployment

### With LANCache (Phase 3)
- DNS pre-configured
- Game clients use cache automatically
- No client configuration needed
- Massive bandwidth savings

### With File Server (Phase 4)
- Roaming profiles pre-configured
- Folder redirection set up
- Auto-mount network shares
- Seamless profile switching

## Support

For image building issues:
1. Check build logs
2. Verify ISO integrity
3. Test in VM first
4. Review autounattend.xml syntax
5. Consult Windows deployment documentation

---

**Next**: Deploy image and integrate all components (Phase 6)