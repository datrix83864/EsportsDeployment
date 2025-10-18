# Terraform module for iPXE Boot Server VM
# High School Esports LAN Infrastructure

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

# iPXE Boot Server VM
resource "proxmox_vm_qemu" "ipxe_server" {
  name        = "ipxe-server"
  target_node = var.proxmox_node
  desc        = "iPXE Boot Server - ${var.organization_name}"
  
  # VM specs from config
  cores   = var.vm_cores
  memory  = var.vm_memory
  sockets = 1
  
  # Use cloud-init ready template or ISO
  clone = var.template_name
  
  # Full clone for production
  full_clone = true
  
  # Boot order
  boot = "order=scsi0"
  
  # BIOS settings
  bios = "seabios"
  
  # OS type
  os_type = "cloud-init"
  
  # CPU type (host for best performance)
  cpu = "host"
  
  # Enable QEMU agent
  agent = 1
  
  # Network configuration
  network {
    bridge    = var.network_bridge
    model     = "virtio"
    firewall  = false
    link_down = false
  }
  
  # Disk configuration
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "${var.disk_size}G"
    cache   = "writethrough"
    ssd     = 1
    discard = "on"
  }
  
  # Cloud-init configuration
  ipconfig0 = "ip=${var.server_ip}/${var.subnet_cidr},gw=${var.gateway}"
  
  nameserver = var.dns_servers
  
  # SSH keys for access
  sshkeys = var.ssh_public_keys
  
  # Cloud-init user
  ciuser     = "ansible"
  cipassword = var.ci_password
  
  # Lifecycle
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
  
  # Tags for identification
  tags = "ipxe,infrastructure,${var.organization_short}"
  
  # Start VM after creation
  automatic_reboot = false
  onboot          = true
  
  # Connection settings for provisioning
  connection {
    type        = "ssh"
    user        = "ansible"
    private_key = var.ssh_private_key
    host        = var.server_ip
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