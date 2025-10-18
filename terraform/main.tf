# Main Terraform Configuration
# High School Esports LAN Infrastructure

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> v3.0.2-rc04"
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
  # Prefer var.config (passed via terraform.tfvars.json) when provided by the deploy script.
  # Fall back to reading the config file directly for interactive use / testing.
  config = length(keys(var.config)) > 0 ? var.config : yamldecode(file("../config.yaml"))

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

// Module-based deployment for touchless flow
module "ipxe_vm" {
  source = "./modules/ipxe_vm"
  config = local.config
  // fallbacks are available in module variables
  organization_name  = local.org_name
  organization_short = local.org_short
}

module "lancache_vm" {
  source = "./modules/lancache_vm"
  config = local.config
  organization_name  = local.org_name
  organization_short = local.org_short
}

module "fileserver_vm" {
  source = "./modules/fileserver_vm"
  config = local.config
  organization_name  = local.org_name
  organization_short = local.org_short
}

// Outputs from modules
output "ipxe_server_id" {
  description = "iPXE Server VM ID"
  value       = module.ipxe_vm.vm_id
}

output "ipxe_server_ip" {
  description = "iPXE Server IP Address"
  value       = module.ipxe_vm.vm_ip
}

output "ipxe_server_name" {
  description = "iPXE Server Name"
  value       = module.ipxe_vm.vm_name
}

output "lancache_server_id" {
  value = module.lancache_vm.vm_id
}
output "lancache_server_ip" {
  value = module.lancache_vm.vm_ip
}
output "lancache_server_name" {
  value = module.lancache_vm.vm_name
}

output "file_server_id" {
  value = module.fileserver_vm.vm_id
}
output "file_server_ip" {
  value = module.fileserver_vm.vm_ip
}
output "file_server_name" {
  value = module.fileserver_vm.vm_name
}