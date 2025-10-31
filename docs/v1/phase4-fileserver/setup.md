# File Server Setup Guide

This guide walks you through setting up the file server for roaming user profiles, enabling players to seamlessly switch between machines.

## What This Solves (ELI5)

**The Problem:**
- Player is using PC #47
- They've spent 10 minutes configuring Fortnite settings
- PC #47 crashes mid-tournament
- Player moves to PC #89
- Has to reconfigure EVERYTHING again 😢

**The Solution:**
- Player logs in on PC #47
- Settings are saved to the file server
- PC #47 crashes
- Player logs in on PC #89
- Settings automatically load from server
- Back in game in 5 minutes! 🎉

## How It Works

```
Login:
1. Player logs into any PC
2. Windows asks file server: "Do you have player1's profile?"
3. File server: "Yes! Here it is" → Downloads profile
4. Player sees their desktop, settings, everything

Logout:
1. Player logs out
2. Windows: "Here are the changes" → Uploads to file server
3. File server saves changes
4. Next login anywhere gets the updates
```

## Prerequisites

- Phases 1-3 complete
- Proxmox server running
- Large storage for profiles (5TB recommended)
- `config.yaml` configured

## Step 1: Configure File Server Settings

Edit `config.yaml`:

```yaml
network:
  file_server_ip: "192.168.1.12"

vms:
  file_server:
    cores: 4
    memory: 8192    # 8GB minimum
    disk_size: 100  # OS disk
    data_disk_size: 5000  # 5TB for profiles

profiles:
  roaming_profiles:
    enabled: true
    path: "\\\\192.168.1.12\\profiles"
  
  max_profile_size_mb: 2048  # 2GB limit per user
  
  folder_redirection:
    documents: "G:\\UserData\\Documents"
    downloads: "G:\\UserData\\Downloads"
    videos: "G:\\UserData\\Videos"
    pictures: "G:\\UserData\\Pictures"
```

Validate:
```bash
python3 scripts/validate_config.py config.yaml
```

## Step 2: Deploy File Server

### Automated (Recommended)

```bash
./deploy.sh --component fileserver
```

⏱️ **Time**: 10-15 minutes

### Manual

```bash
# Create VM
cd terraform
terraform apply -target=module.fileserver_vm

# Deploy configuration
cd ../ansible
ansible-playbook playbooks/deploy_fileserver.yml
```

## Step 3: Create User Accounts

### Single User

```bash
ssh ansible@192.168.1.12
sudo create-user player1 password123
```

### Bulk Users (200 players)

```bash
ssh ansible@192.168.1.12
sudo create-bulk-users player 200 password123
```

This creates: player001, player002, ..., player200

### Admin Users

```bash
# Create admin user
sudo useradd -m -G admins admin1
sudo usermod -aG admins admin1
(echo "adminpass"; echo "adminpass") | sudo smbpasswd -a admin1 -s
```

## Step 4: Test File Server

### From File Server

```bash
# List Samba users
sudo pdbedit -L

# Test local access
smbclient //localhost/profiles -U player1
# Enter password
# Should see: smb: \>

# List shares
smbclient -L localhost -U player1
```

### From Your Workstation

```bash
# Linux/Mac
smbclient //192.168.1.12/profiles -U player1

# Windows (PowerShell)
net use * \\192.168.1.12\profiles password123 /user:player1
```

If you can connect, file server is working! ✅

## Step 5: Verify Profile Template

```bash
ssh ansible@192.168.1.12
ls -la /srv/profiles/player001/
```

You should see:
```
Desktop/
Documents/
Downloads/
Welcome.txt (on Desktop)
```

## Step 6: Check Status

```bash
ssh ansible@192.168.1.12 'fileserver-status'
```

Expected output:
```
File Server Status
==================

Services:
Active: active (running)
Active: active (running)

Active Connections:
0

Disk Usage:
/dev/sdb        5.0T   1.0G  5.0T   1% /srv

Profile Storage:
200M    /srv/profiles

Top 5 Largest Profiles:
1.2M    /srv/profiles/player001
1.2M    /srv/profiles/player002
```

## Monitoring

### Active Connections

```bash
sudo smbstatus
```

Shows who's connected and what files they're accessing.

### Profile Sizes

```bash
profile-sizes
```

Shows all users and their profile sizes. Warns if over limit.

### Disk Usage

```bash
df -h /srv
```

Watch this during events - profiles add up fast!

### Live Logs

```bash
sudo tail -f /var/log/samba/log.smbd
```

See real-time file access.

## Common Tasks

### Reset User Password

```bash
sudo smbpasswd player001
# Enter new password twice
```

### Delete User

```bash
# Archives profile to /srv/backups first
sudo delete-user player001
```

### Backup Profiles

```bash
# Backup all profiles
sudo backup-profiles

# Backup specific user
sudo backup-profiles player001
```

Backups saved to `/srv/backups/`

### Clean Large Profiles

```bash
# Clean specific user
sudo clean-profiles player001

# Auto-clean all profiles over limit
sudo clean-profiles --auto
```

Removes temp files, logs, cache.

## Troubleshooting

### Can't Connect from Client

**Check firewall:**
```bash
sudo ufw status
# Should allow ports 139, 445
```

**Check Samba is running:**
```bash
sudo systemctl status smbd
```

**Test network:**
```bash
ping 192.168.1.12
telnet 192.168.1.12 445
```

### Wrong Password Error

**Reset password:**
```bash
sudo smbpasswd player001
```

**Check user exists:**
```bash
sudo pdbedit -L | grep player001
```

### Profile Won't Load

**Check profile exists:**
```bash
ls -la /srv/profiles/player001
```

**Check permissions:**
```bash
sudo chown -R player001:users /srv/profiles/player001
sudo chmod 700 /srv/profiles/player001
```

**Check profile size:**
```bash
du -sh /srv/profiles/player001
# If > 2GB, clean it
sudo clean-profiles player001
```

### Slow Profile Loading

**Check profile size:**
- Over 2GB = slow
- Keep under 1GB for best performance

**Check network speed:**
```bash
iperf3 -s  # On file server
iperf3 -c 192.168.1.12  # From client
```

Should see near line-speed.

**Use folder redirection:**
- Large files go to local G: drive
- Only settings in profile
- Much faster!

## Performance Tips

### For 200 Concurrent Logins

**Increase VM resources:**
```yaml
vms:
  file_server:
    cores: 8      # More cores = more concurrent access
    memory: 16384 # 16GB for better caching
```

**Use SSD for profiles:**
- 10x faster than HDD
- Critical for large deployments
- Profiles on SSD, backups on HDD

**Enable caching in Samba:**
Already configured in smb.conf:
```
socket options = TCP_NODELAY SO_RCVBUF=131072 SO_SNDBUF=131072
```

### Network Optimization

**10Gb networking:**
- Profiles load 10x faster
- Handle 200 concurrent users
- Essential for large events

**SMB3 multichannel:**
Already enabled in configuration for better throughput.

## Pre-Event Checklist

One week before:
- [ ] File server deployed and tested
- [ ] All user accounts created
- [ ] Profile template customized
- [ ] Test with 10 simultaneous logins
- [ ] Backup system tested
- [ ] Monitoring working

Day before:
- [ ] Verify all services running
- [ ] Check disk space
- [ ] Test profile loading speed
- [ ] Brief staff on user management
- [ ] Backup existing profiles

During event:
- [ ] Monitor active connections
- [ ] Watch disk space
- [ ] Check for profile errors
- [ ] Ready to reset profiles if needed

## Integration with Windows (Phase 5)

The Windows image will be configured to:
1. Automatically use roaming profiles
2. Redirect folders to G: drive
3. Apply profile on login
4. Save changes on logout

All automatic - no user configuration needed!

## Best Practices

### Profile Management
- Keep profiles under 2GB
- Clean regularly
- Backup before events
- Archive old profiles

### User Accounts
- Use strong passwords for admins
- Simple passwords OK for players (tournament only)
- Reset passwords after events
- Disable accounts when not needed

### Storage Management
- Monitor disk usage daily
- Plan for ~1GB per active user
- Plus ~500MB per casual user
- Archive old tournaments

### Security
- Restrict admin access
- Monitor failed logins
- Use firewall rules
- Regular backups

## Quick Reference

```bash
# User Management
create-user <username> <password>
delete-user <username>
create-bulk-users <prefix> <count> <password>
smbpasswd <username>  # Reset password

# Monitoring
fileserver-status     # Overall status
profile-sizes         # Profile sizes
smbstatus            # Active connections
sudo tail -f /var/log/samba/log.smbd  # Live logs

# Maintenance
backup-profiles [username]
clean-profiles <username|--auto>
df -h /srv           # Disk space

# Troubleshooting
sudo systemctl status smbd
sudo testparm -s     # Verify Samba config
smbclient -L localhost -U <user>  # Test locally
```

## Next Steps

✅ File server is ready!

Next in Phase 5:
- Build Windows 11 image
- Install game clients
- Configure roaming profiles
- Set up folder redirection
- Create final deployment image

Continue to: [Phase 5 - Windows Image Builder](../phase5-windows/setup.md)

---

**Phase 4 Complete!** Users can now seamlessly switch machines with all their settings intact. 🎉