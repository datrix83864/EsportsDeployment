# Getting Started Guide

Welcome! This guide will walk you through setting up your High School Esports LAN Infrastructure from scratch. We've designed this to be as simple as possible - if you can follow a recipe, you can do this!

## What You're Building

Think of this like setting up a giant gaming cafe, but smarter:

- **iPXE Server**: Like a vending machine that gives every computer a fresh Windows install when it boots up
- **LANCache**: Like having your own mini-Steam/Epic store so 200 computers don't all download games from the internet
- **File Server**: Keeps player settings so they can move between computers without losing their configs
- **Windows Image**: A pre-made Windows setup with all the games and programs already installed

## Before You Start

### What You Need

#### Hardware

- 1 beefy server with:
  - Proxmox VE installed (we'll help with this)
  - At least 40TB of hard drive space
  - At least 388GB of RAM (more is better!)
  - Fast network connection (10 gigabit is great, 1 gigabit works)
  
- Network switches:
  - We assume UniFi switches, but others work too
  - Managed switches preferred
  
- Client gaming PCs (up to 200):
  - Each with a 2TB drive (HDD or SSD)
  - PXE boot capable (most modern PCs support this)
  - At least 16GB RAM

#### Software on Your Computer

- Visual Studio Code (for editing config files)
- Git (for downloading this project)
- SSH client (built into Windows 10/11, Mac, and Linux)

### Time Required

- First-time setup: 4-6 hours
- Once you've done it: 2-3 hours

## Step 1: Get the Code

Think of this like downloading a recipe book:

```bash
# Open your terminal/command prompt
git clone https://github.com/your-org/esports-lan-infrastructure.git
cd esports-lan-infrastructure
```

## Step 2: Install Required Tools

We need a few helper programs. Don't worry, we'll walk you through it!

### On Windows (using WSL2)

```bash
# Open PowerShell as Administrator and install WSL2
wsl --install

# Restart your computer, then open Ubuntu from the Start menu
# Inside Ubuntu, run:
sudo apt update
sudo apt install -y python3 python3-pip ansible git

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.13.4/terraform_1.13.4_linux_amd64.zip
unzip terraform_1.13.4_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### On Mac

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install python3 ansible terraform git
```

### On Linux

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y python3 python3-pip ansible git

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.13.4/terraform_1.13.4_linux_amd64.zip
unzip terraform_1.13.4_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Fedora/RHEL
sudo dnf install -y python3 python3-pip ansible git
```

## Step 3: Set Up Your Configuration

This is where you customize everything for your organization.

```bash
# Copy the example config
cp config.example.yaml config.yaml

# Open it in VS Code
code config.yaml
```

Now edit the file. Here's what to change:

### Organization Info

```yaml
organization:
  name: "Lincoln High School Esports"  # Your school/org name
  short_name: "LHS"                    # Short name (used in computer names)
  contact_email: "esports@lincoln.edu"
```

### Network Settings

```yaml
network:
  # Pick IP addresses that don't conflict with your network
  ipxe_server_ip: "192.168.1.10"      # Change if needed
  lancache_server_ip: "192.168.1.11"  # Change if needed
  file_server_ip: "192.168.1.12"      # Change if needed
  
  subnet: "192.168.1.0/24"             # Your network range
  gateway: "192.168.1.1"               # Your router IP
  
  # DHCP range for gaming PCs (adjust to fit your network)
  dhcp_range_start: "192.168.1.100"
  dhcp_range_end: "192.168.1.254"
```

**Important**: Make sure these IPs don't conflict with anything else on your network!

### Proxmox Settings

```yaml
proxmox:
  host: "proxmox.local"     # Or your Proxmox server's IP
  node_name: "pve"          # Usually "pve" by default
  
  # Check your Proxmox storage names (look in Proxmox web UI)
  vm_storage: "local-lvm"
  iso_storage: "local"
```

### Games to Support

```yaml
games:
  enabled:
    - fortnite
    - rocket_league
    - valorant
    - league_of_legends
    - overwatch2
    - marvel_rivals
    # Add others if needed:
    # - overcooked2
    # - csgo
```

Save the file when you're done!

## Step 4: Validate Your Configuration

Let's make sure everything looks good:

```bash
python3 scripts/validate_config.py config.yaml
```

If you see errors, go back and fix them. The error messages will tell you what's wrong.

## Step 5: Check Your Setup

Before we start building, let's make sure everything is ready:

```bash
./scripts/preflight_check.sh
```

This checks:

- Can we reach your Proxmox server?
- Do you have enough disk space?
- Are the IP addresses available?

## Step 6: Deploy

Now for the exciting part. This will take about 30-60 minutes:

```bash
# First, do a dry run to see what will happen
./deploy.sh --dry-run

# If everything looks good, do the real deployment
./deploy.sh
```

Grab a coffee ☕ and watch the magic happen!

## Step 7: Build Your Windows Image

Once the servers are deployed, we need to create the Windows image:

```bash
./scripts/build_windows_image.sh
```

This will:

1. Create a temporary VM in Proxmox
2. Install Windows 11
3. Install all the games and programs
4. Optimize everything
5. Create an image file that will be loaded on all client machines

This takes 2-3 hours, so maybe grab lunch 🍕

## Step 8: Test PXE Boot

Time to test with a client machine!

1. Plug a gaming PC into your network
2. Turn it on and press F12 (or whatever key boots to network)
3. Select "Network Boot" or "PXE Boot"
4. Watch it load Windows from your server!

The first boot takes about 5-10 minutes. Subsequent boots are faster.

## Step 9: Create User Accounts

Users need accounts to log in. We'll create a simple system:

```bash
# Create a tournament admin account
./scripts/create_user.sh admin password123

# Create player accounts (usually teams do this)
./scripts/create_user.sh player1 temppass
./scripts/create_user.sh player2 temppass
```

Players can change their passwords after first login.

## Troubleshooting

### "Can't reach Proxmox server"

- Make sure you can ping the Proxmox IP: `ping 192.168.1.x`
- Check firewall settings on the Proxmox server
- Verify the IP in config.yaml is correct

### "PXE boot fails"

- Check DHCP settings on your network
- Make sure the iPXE server VM is running
- Verify client PCs have PXE boot enabled in BIOS

### "Games download slowly"

- This is normal the first time! LANCache needs to download once
- After the first download, subsequent machines will be fast
- You can pre-download games using `./scripts/prefill_cache.sh`

### "User profiles are slow"

- Check network speed between clients and file server
- Consider enabling folder redirection (see config.yaml)
- Make sure file server has enough RAM

### Still stuck?

- Check docs/troubleshooting.md for more help
- Look at the logs: `./scripts/view_logs.sh`
- Open an issue on GitHub

## What's Next?

Now that everything is set up:

1. **Before an Event**:
   - Run `./scripts/prefill_cache.sh` to download all games
   - Test with a few machines
   - Create user accounts

2. **During an Event**:
   - Monitor with `./scripts/monitor.sh`
   - Help players who need account help
   - Reboot problem machines (they'll get fresh images!)

3. **After an Event**:
   - Back up user data if needed: `./scripts/backup.sh`
   - Update games: `./scripts/update_games.sh`

## Advanced Topics

Once you're comfortable, check out:

- [Custom Branding](customization.md) - Add your logo and wallpapers
- [Performance Tuning](performance-tuning.md) - Optimize for your hardware
- [High Availability Setup](high-availability.md) - Use multiple servers
- [Monitoring and Logging](monitoring.md) - Keep tabs on everything

## Getting Help

- **Documentation**: Check the docs/ folder
- **GitHub Issues**: Report bugs or ask questions
- **Discord**: Join our community (link in README)

## You Did It! 🎉

Congratulations! You now have a professional esports infrastructure. Your tournaments will run smoother, and setup will be a breeze.

Remember: The first time is the hardest. After that, you'll be deploying this in your sleep!

---

**Quick Reference Card** (print this out!)

```
Start everything:    ./deploy.sh
Stop everything:     ./scripts/stop_all.sh
View status:         ./scripts/status.sh
View logs:           ./scripts/view_logs.sh
Troubleshoot:        ./scripts/troubleshoot.sh
Backup:              ./scripts/backup.sh
Update config:       Edit config.yaml, then ./deploy.sh --component <name>
```