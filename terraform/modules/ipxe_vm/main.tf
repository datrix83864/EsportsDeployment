# Terraform module for iPXE Boot Server VM
# High School Esports LAN Infrastructure

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

# iPXE Boot Server VM
resource "proxmox_vm_qemu" "ipxe_server" {
  name        = "ipxe-server"
  target_node = var.proxmox_node
  description = "iPXE Boot Server - ${var.organization_name}"

  # VM specs from config (prefer var.config)
  memory  = (length(keys(var.config)) > 0 && try(var.config.vms.ipxe_server.memory, null) != null) ? var.config.vms.ipxe_server.memory : var.vm_memory

  
  # Use cloud-init ready template if provided; otherwise fall back to attaching an ISO (if provided)
  clone = var.template_name != "" ? var.template_name : null
  
  # Full clone for production
  full_clone = true
  
  # Boot order
  boot = "order=scsi0"
  
  # BIOS settings
  bios = "seabios"
  
  # OS type
  os_type = "cloud-init"
  
  # CPU type (host for best performance)
  cpu {
    cores = (length(keys(var.config)) > 0 && try(var.config.vms.ipxe_server.cores, null) != null) ? var.config.vms.ipxe_server.cores : var.vm_cores
    type  = "host"
  }
  
  # Enable QEMU agent
  agent = 1
  
  # Network configuration
  network {
    id        = 0
    bridge    = var.network_bridge
    model     = "virtio"
    firewall  = false
    link_down = false
  }
  
  # Disk configuration
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.storage_pool
    size    = "${(length(keys(var.config)) > 0 && try(var.config.vms.ipxe_server.disk_size, null) != null) ? var.config.vms.ipxe_server.disk_size : var.disk_size}G"
    cache   = "writethrough"
    discard = true
  }

  # If a template was not provided, allow attaching an ISO for manual install or automated kickstart
  # If an ISO is provided (and no template is used) attach it as a cdrom on IDE2
  dynamic "disk" {
    for_each = var.ubuntu_iso != "" && var.template_name == "" ? [1] : []
    content {
      slot = "ide2"
      type = "cdrom"
      file = var.ubuntu_iso
    }
  }
  
  # Cloud-init configuration
  ipconfig0 = "ip=${(length(keys(var.config)) > 0 && try(var.config.network.ipxe_server_ip, null) != null) ? var.config.network.ipxe_server_ip : var.server_ip}/${var.subnet_cidr},gw=${(length(keys(var.config)) > 0 && try(var.config.network.gateway, null) != null) ? var.config.network.gateway : var.gateway}"

  nameserver = (length(keys(var.config)) > 0 && try(join(" ", [var.config.network.lancache_server_ip, "8.8.8.8"]), null) != null) ? join(" ", [var.config.network.lancache_server_ip, "8.8.8.8"]) : var.dns_servers
  
  # SSH keys for access
  sshkeys = (length(keys(var.config)) > 0 && try(var.config.ssh_public_key, null) != null) ? var.config.ssh_public_key : var.ssh_public_keys
  
  # Cloud-init user
  ciuser     = "ansible"
  cipassword = (length(keys(var.config)) > 0 && try(var.config.windows.admin_password_hash, null) != null) ? var.config.windows.admin_password_hash : var.ci_password
  
  # Lifecycle
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
  
  # Tags for identification
  tags = "ipxe,infrastructure,${(length(keys(var.config)) > 0 && try(var.config.organization.short_name, null) != null) ? var.config.organization.short_name : var.organization_short}"
  
  # Start VM after creation
  automatic_reboot = false
  onboot          = true
  
  # Connection settings for provisioning
  connection {
    type        = "ssh"
    user        = "ansible"
    private_key = (length(keys(var.config)) > 0 && try(var.config.ssh_private_key, null) != null) ? var.config.ssh_private_key : var.ssh_private_key
    host        = (length(keys(var.config)) > 0 && try(var.config.network.ipxe_server_ip, null) != null) ? var.config.network.ipxe_server_ip : var.server_ip
    timeout     = "5m"
  }
  
  # Wait for cloud-init to complete
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "echo 'Cloud-init complete'"
    ]
  }
}

# Output the VM ID for reference
output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_vm_qemu.ipxe_server.id
}

output "vm_ip" {
  description = "iPXE server IP address"
  value       = var.server_ip
}

output "vm_name" {
  description = "iPXE server VM name"
  value       = proxmox_vm_qemu.ipxe_server.name
}