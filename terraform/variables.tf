// Auto-generated variable stubs for values produced by convert_config_for_terraform()
// These are conservative declarations to avoid Terraform warnings about undeclared variables.

variable "organization_name" {
  description = "Organization full name"
  type        = string
  default     = ""
}

variable "organization_short_name" {
  description = "Organization short name"
  type        = string
  default     = ""
}

variable "contact_email" {
  description = "Contact email for organization"
  type        = string
  default     = ""
}

// Network values (flattened as network_<key>)
variable "network_ipxe_server_ip" {
  type    = string
  default = ""
}

variable "network_lancache_server_ip" {
  type    = string
  default = ""
}

variable "network_file_server_ip" {
  type    = string
  default = ""
}

variable "network_subnet" {
  type    = string
  default = ""
}

// Proxmox flatten
variable "proxmox_host" {
  type    = string
  default = ""
}

variable "proxmox_node_name" {
  type    = string
  default = ""
}

variable "proxmox_vm_storage" {
  type    = string
  default = ""
}

variable "proxmox_iso_storage" {
  type    = string
  default = ""
}

// VM configs and larger structures
variable "vms" {
  description = "VM configuration block (passed through from config.yaml)"
  type        = any
  default     = {}
}

variable "games" {
  type    = any
  default = {}
}

variable "communication" {
  type    = any
  default = {}
}

variable "windows" {
  type    = any
  default = {}
}

variable "profiles" {
  type    = any
  default = {}
}

variable "backup" {
  type    = any
  default = {}
}

variable "monitoring" {
  type    = any
  default = {}
}

variable "advanced" {
  type    = any
  default = {}
}

// Full config pass-through (preferred method)
variable "config" {
  description = "Full configuration object (from config.yaml). Use this instead of many flattened variables."
  type        = any
  default     = {}
}

// Provider and root-level variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = ""
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token id"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_user" {
  description = "Proxmox username (alternative to token)"
  type        = string
  default     = ""
}

variable "proxmox_password" {
  description = "Proxmox password (alternative to token)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Whether to skip TLS verification for Proxmox provider"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Default Proxmox node name"
  type        = string
  default     = ""
}

variable "ubuntu_iso" {
  description = "Path or identifier for Ubuntu ISO"
  type        = string
  default     = ""
}

variable "vm_storage" {
  description = "Default storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Default network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Optional VLAN tag"
  type        = any
  default     = null
}

variable "subnet_cidr" {
  description = "Subnet CIDR bits (e.g., 24)"
  type        = number
  default     = 24
}

variable "ssh_public_key" {
  description = "SSH public key to inject into VMs"
  type        = string
  default     = ""
  sensitive   = true
}

