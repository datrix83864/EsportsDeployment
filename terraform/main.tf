# Main Terraform Configuration
# High School Esports LAN Infrastructure

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

# Proxmox Provider Configuration
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  
  # Or use username/password (less secure)
  pm_user     = var.proxmox_user
  pm_password = var.proxmox_password
  
  # For self-signed certificates
  pm_tls_insecure = var.proxmox_tls_insecure
  
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_debug      = true
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# Local variables from config.yaml
locals {
  config = yamldecode(file("../config.yaml"))
  
  org_name       = local.config.organization.name
  org_short      = local.config.organization.short_name
  
  ipxe_ip        = local.config.network.ipxe_server_ip
  lancache_ip    = local.config.network.lancache_server_ip
  fileserver_ip  = local.config.network.file_server_ip
  gateway        = local.config.network.gateway
  
  ipxe_cores     = local.config.vms.ipxe_server.cores
  ipxe_memory    = local.config.vms.ipxe_server.memory
  ipxe_disk      = local.config.vms.ipxe_server.disk_size
}

# iPXE Boot Server VM
resource "proxmox_vm_qemu" "ipxe_server" {
  name        = "ipxe-server"
  target_node = var.proxmox_node
  desc        = "${local.org_name} - iPXE Boot Server"
  
  # VM Resources
  cores   = local.ipxe_cores
  sockets = 1
  memory  = local.ipxe_memory
  
  # Use cloud-init image or ISO
  # Option 1: Clone from template (if you have one)
  # clone = "ubuntu-22.04-template"
  
  # Option 2: Use ISO (slower but works without template)
  iso = var.ubuntu_iso
  
  # Boot settings
  boot = "order=scsi0;ide2;net0"
  
  # OS Settings
  os_type = "cloud-init"
  
  # BIOS
  bios = "seabios"
  
  # CPU
  cpu = "host"
  
  # Enable QEMU agent
  agent = 1
  
  # Network
  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = var.vlan_id
  }
  
  # Disk
  disk {
    type    = "scsi"
    storage = var.vm_storage
    size    = "${local.ipxe_disk}G"
    cache   = "writethrough"
    ssd     = 1
  }
  
  # Cloud-init settings
  ipconfig0 = "ip=${local.ipxe_ip}/${var.subnet_cidr},gw=${local.gateway}"
  
  nameserver = "${local.lancache_ip} 8.8.8.8"
  
  # SSH keys
  sshkeys = var.ssh_public_key
  
  # Cloud-init user
  ciuser = "ansible"
  
  # Lifecycle
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
  
  # Don't start automatically (we need to configure first)
  automatic_reboot = false
  onboot           = true
}

# Outputs
output "ipxe_server_id" {
  description = "iPXE Server VM ID"
  value       = proxmox_vm_qemu.ipxe_server.vmid
}

output "ipxe_server_ip" {
  description = "iPXE Server IP Address"
  value       = local.ipxe_ip
}

output "ipxe_server_name" {
  description = "iPXE Server Name"
  value       = proxmox_vm_qemu.ipxe_server.name
}