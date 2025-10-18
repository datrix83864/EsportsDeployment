# Variables for iPXE VM Terraform Module

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "organization_name" {
  description = "Organization name for VM description"
  type        = string
  default     = ""
}

variable "organization_short" {
  description = "Organization short name for tagging"
  type        = string
  default     = ""
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 32
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge to use"
  type        = string
  default     = "vmbr0"
}

variable "server_ip" {
  description = "Static IP address for iPXE server"
  type        = string
  default     = ""
}

variable "subnet_cidr" {
  description = "Subnet CIDR bits (e.g., 24 for /24)"
  type        = number
  default     = 24
}

variable "gateway" {
  description = "Network gateway IP"
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "DNS servers (space-separated)"
  type        = string
  default     = "8.8.8.8 8.8.4.4"
}

variable "template_name" {
  description = "Name of cloud-init template to clone"
  type        = string
  default     = "ubuntu-22.04-cloudinit"
}

variable "ssh_public_keys" {
  description = "SSH public keys for access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_private_key" {
  description = "SSH private key for provisioning"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ci_password" {
  description = "Cloud-init user password"
  type        = string
  sensitive   = true
  default     = ""
}

// Full config object pass-through (optional)
variable "config" {
  description = "Full configuration object (from config.yaml). Module will prefer values from this when provided."
  type        = any
  default     = {}
}