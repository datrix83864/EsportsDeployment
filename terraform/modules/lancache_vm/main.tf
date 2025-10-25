// Terraform module for LANCache VM

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

resource "proxmox_vm_qemu" "lancache_server" {
  name        = "lancache-server"
  target_node = (length(keys(var.config)) > 0 && try(var.config.proxmox.node_name, "") != "") ? var.config.proxmox.node_name : var.proxmox_node
  description = "LANCache Server - ${var.organization_name}"

  memory  = (length(keys(var.config)) > 0 && try(var.config.vms.lancache_server.memory, null) != null) ? var.config.vms.lancache_server.memory : var.vm_memory


  clone = var.template_name != "" ? var.template_name : null
  full_clone = true

  boot = "order=scsi0"
  bios = "seabios"
  os_type = "cloud-init"
  cpu {
    cores = (length(keys(var.config)) > 0 && try(var.config.vms.lancache_server.cores, null) != null) ? var.config.vms.lancache_server.cores : var.vm_cores
    type  = "host"
  }
  agent = 1

  network {
    id     = 0
    bridge = var.network_bridge
    model  = "virtio"
  }

  # Boot disk - cloned from template
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.storage_pool
    size    = "${(length(keys(var.config)) > 0 && try(var.config.vms.lancache_server.disk_size, null) != null) ? var.config.vms.lancache_server.disk_size : var.disk_size}G"
    cache   = "writethrough"
  }

  # Cloud-init drive (ide2) - REQUIRED for cloud-init to work!
  disk {
    slot = "ide2"
    type = var.ubuntu_iso != "" && var.template_name == "" ? "cdrom" : "cloudinit"
    iso  = var.ubuntu_iso != "" && var.template_name == "" ? var.ubuntu_iso : null
    storage = var.ubuntu_iso == "" || var.template_name != "" ? var.storage_pool : null
  }

  ipconfig0 = "ip=${(length(keys(var.config)) > 0 && try(var.config.network.lancache_server_ip, null) != null) ? var.config.network.lancache_server_ip : var.server_ip}/${var.subnet_cidr},gw=${(length(keys(var.config)) > 0 && try(var.config.network.gateway, null) != null) ? var.config.network.gateway : var.gateway}"

  nameserver = (length(keys(var.config)) > 0 && try(join(" ", [var.config.network.lancache_server_ip, "8.8.8.8"]), null) != null) ? join(" ", [var.config.network.lancache_server_ip, "8.8.8.8"]) : var.dns_servers

  sshkeys = (length(keys(var.config)) > 0 && try(var.config.ssh_public_key, null) != null) ? var.config.ssh_public_key : var.ssh_public_keys

  ciuser     = "ansible"
  cipassword = (length(keys(var.config)) > 0 && try(var.config.windows.admin_password_hash, null) != null) ? var.config.windows.admin_password_hash : var.ci_password

  lifecycle { ignore_changes = [ network, disk ] }

  tags = "lancache,infrastructure,${(length(keys(var.config)) > 0 && try(var.config.organization.short_name, null) != null) ? var.config.organization.short_name : var.organization_short}"

  automatic_reboot = false
  onboot = true

  connection {
    type = "ssh"
    user = "ansible"
    private_key = (length(keys(var.config)) > 0 && try(var.config.ssh_private_key, null) != null) ? var.config.ssh_private_key : var.ssh_private_key
    host = (length(keys(var.config)) > 0 && try(var.config.network.lancache_server_ip, null) != null) ? var.config.network.lancache_server_ip : var.server_ip
    timeout = "5m"
  }

  provisioner "remote-exec" { inline = ["cloud-init status --wait", "echo 'Cloud-init complete'"] }
}

output "vm_id" { value = proxmox_vm_qemu.lancache_server.id }
output "vm_ip" { value = (length(keys(var.config)) > 0 && try(var.config.network.lancache_server_ip, null) != null) ? var.config.network.lancache_server_ip : var.server_ip }
output "vm_name" { value = proxmox_vm_qemu.lancache_server.name }
