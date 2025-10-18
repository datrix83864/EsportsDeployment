# iPXE Boot Server

The iPXE boot server provides network boot capabilities for all client machines. When a client boots, it receives an IP address via DHCP and loads a boot menu via TFTP, allowing it to load the Windows image from the network.

## Architecture

```
Client Machine Boot Sequence:
1. Power on → PXE ROM loads
2. DHCP request → Receives IP + boot server info
3. TFTP download → Gets iPXE bootloader
4. iPXE loads → Presents boot menu
5. User selects Windows → Downloads and boots image
```

## Components

### 1. DHCP Server (dnsmasq)
- Assigns IP addresses to clients
- Provides PXE boot information
- Lightweight and reliable

### 2. TFTP Server (tftpd-hpa)
- Serves boot files to clients
- iPXE bootloader files
- Boot menu configuration

### 3. HTTP Server (nginx)
- Serves Windows boot images (WIM files)
- Much faster than TFTP for large files
- Serves boot scripts and configuration

### 4. iPXE Boot Menu
- Customizable boot options
- Auto-boot with timeout
- Manual boot selection
- Diagnostic tools

## Directory Structure

```
ipxe/
├── config/
│   ├── dnsmasq.conf.j2          # DHCP/TFTP configuration
│   ├── boot.ipxe.j2             # iPXE boot menu
│   └── nginx.conf.j2            # HTTP server for images
│
├── scripts/
│   ├── setup.sh                 # Initial setup script
│   ├── test_pxe.sh              # Test PXE functionality
│   └── update_boot_menu.sh      # Update boot menu
│
├── files/
│   ├── ipxe.efi                 # UEFI bootloader
│   ├── undionly.kpxe            # BIOS bootloader
│   └── wimboot                  # Windows boot loader
│
└── README.md                    # This file
```

## Network Requirements

### IP Addressing
- iPXE Server: Static IP (from config.yaml)
- DHCP Range: Defined in config.yaml
- Gateway: Network router
- DNS: External or internal DNS servers

### Ports Used
- **UDP 67**: DHCP server
- **UDP 69**: TFTP server
- **TCP 80**: HTTP server (boot files)
- **TCP 8080**: HTTP server (images)

### Firewall Rules
```bash
# Allow DHCP
sudo ufw allow 67/udp

# Allow TFTP
sudo ufw allow 69/udp

# Allow HTTP
sudo ufw allow 80/tcp
sudo ufw allow 8080/tcp
```

## Configuration

All configuration is managed through `config.yaml`:

```yaml
network:
  ipxe_server_ip: "192.168.1.10"
  dhcp_range_start: "192.168.1.100"
  dhcp_range_end: "192.168.1.254"
  gateway: "192.168.1.1"
  dns_primary: "8.8.8.8"

advanced:
  pxe:
    timeout_seconds: 5
    default_boot: "windows"
```

## Installation

### Automated (Recommended)
```bash
# From project root
./deploy.sh --component ipxe
```

### Manual
```bash
cd ipxe/scripts
sudo ./setup.sh
```

## Boot Menu Options

The default boot menu includes:

1. **Boot Windows 11** (default)
   - Loads from network
   - Fresh image every boot
   - Auto-selected after timeout

2. **Boot from Local Disk**
   - Boots from hard drive
   - Useful for troubleshooting

3. **Network Information**
   - Shows IP address
   - Shows MAC address
   - Shows boot server info

4. **Reboot**
   - Restarts the computer

## Testing

### Test DHCP
```bash
# From another machine on the network
sudo nmap --script broadcast-dhcp-discover
```

### Test TFTP
```bash
# Test TFTP server
tftp 192.168.1.10
> get ipxe.efi
> quit
```

### Test PXE Boot
```bash
# From iPXE server
./scripts/test_pxe.sh
```

Or boot a test client machine via network boot.

## Troubleshooting

### Client doesn't get IP address
1. Check DHCP server is running:
   ```bash
   sudo systemctl status dnsmasq
   ```

2. Check network connectivity:
   ```bash
   ping <client-ip>
   ```

3. Verify DHCP range in config:
   ```bash
   cat /etc/dnsmasq.conf | grep dhcp-range
   ```

### Client gets IP but doesn't boot
1. Check TFTP server:
   ```bash
   sudo systemctl status tftpd-hpa
   ```

2. Verify boot files exist:
   ```bash
   ls -la /srv/tftp/
   ```

3. Check firewall:
   ```bash
   sudo ufw status
   ```

### Boot menu doesn't appear
1. Check iPXE script syntax:
   ```bash
   cat /srv/tftp/boot.ipxe
   ```

2. Verify HTTP server is running:
   ```bash
   sudo systemctl status nginx
   ```

3. Test boot script manually:
   ```bash
   curl http://192.168.1.10/boot.ipxe
   ```

### Slow boot times
1. Check network speed between client and server
2. Verify no network loops or spanning tree issues
3. Consider using SSD for image storage
4. Enable jumbo frames if supported (MTU 9000)

## Advanced Configuration

### Custom Boot Menu
Edit `config/boot.ipxe.j2` to customize:
- Timeout duration
- Menu colors
- Boot options
- Organization branding

### Multiple Boot Images
Add additional image options:
```ipxe
:menu
menu Select boot option
item windows11    Windows 11 (Latest)
item windows11old Windows 11 (Previous)
item local        Boot from local disk
choose --timeout 5000 --default windows11 selected
goto ${selected}

:windows11
kernel wimboot
initrd windows11-latest.wim
boot

:windows11old
kernel wimboot
initrd windows11-backup.wim
boot
```

### VLAN Support
If using VLANs, configure in dnsmasq:
```conf
# Serve DHCP on specific interface
interface=eth0.100
dhcp-range=192.168.100.10,192.168.100.254,12h
```

## Security Considerations

### Network Isolation
- Consider placing boot network on separate VLAN
- Use firewall rules to restrict access
- Only allow necessary ports

### Boot Integrity
- Use HTTPS for boot scripts (requires certificates)
- Implement secure boot (advanced)
- Monitor boot server logs for anomalies

### Access Control
- Restrict SSH access to boot server
- Use strong passwords
- Enable fail2ban for brute force protection

## Performance Optimization

### Network Optimization
- Enable jumbo frames (MTU 9000) if all equipment supports it
- Use dedicated network interface for PXE traffic
- Consider link aggregation (LACP) for higher throughput

### Storage Optimization
- Store boot images on SSD
- Use RAM disk for frequently accessed files
- Enable nginx caching

### Concurrent Boots
For 200 simultaneous boots:
- Ensure adequate network bandwidth (10Gb recommended)
- Increase nginx worker processes
- Tune DHCP server lease times
- Monitor server CPU and network utilization

## Monitoring

### Check Server Status
```bash
./scripts/monitor_pxe.sh
```

### View Logs
```bash
# DHCP logs
sudo journalctl -u dnsmasq -f

# TFTP logs
sudo journalctl -u tftpd-hpa -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
```

### Key Metrics
- DHCP leases issued
- TFTP requests per second
- HTTP download speeds
- Boot completion times

## Backup and Recovery

### Backup Configuration
```bash
# Backup all configs
sudo tar czf ipxe-backup.tar.gz /etc/dnsmasq.conf /srv/tftp/ /etc/nginx/

# Backup to file server
sudo rsync -av /srv/tftp/ fileserver:/backups/ipxe/
```

### Recovery
```bash
# Restore from backup
sudo tar xzf ipxe-backup.tar.gz -C /

# Restart services
sudo systemctl restart dnsmasq tftpd-hpa nginx
```

## Integration with Other Components

- **LANCache**: Clients use LANCache DNS for game downloads
- **File Server**: Boot process mounts network profiles
- **Windows Image**: Boot menu loads image from file server

## References

- [iPXE Documentation](https://ipxe.org/docs)
- [dnsmasq Man Page](https://thekelleys.org.uk/dnsmasq/doc.html)
- [Windows PE Network Boot](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-network-drivers-initializing-and-adding-drivers)

## Support

For issues specific to the iPXE server:
1. Check logs: `./scripts/view_logs.sh`
2. Run diagnostics: `./scripts/test_pxe.sh`
3. Review troubleshooting section above
4. Check GitHub issues
5. Consult main project documentation