
# Creating a Proxmox cloud-init Template

This repository expects a cloud-init-capable Proxmox template when using the module-based provisioning flow. If you don't have a template on your Proxmox host, you can either:

- Upload an Ubuntu ISO and set `ubuntu_iso` in `terraform/terraform.tfvars` (modules will attach the ISO), or
- Create a cloud-init template on the Proxmox host and set `template_name` (recommended for repeatable deployments).

## Automated script

There is a helper script that will create a Proxmox cloud-init template from an Ubuntu cloud image URL:

Location: `scripts/create_proxmox_cloudinit_template.sh`

Usage example (run locally, you must have SSH access to the Proxmox host):

```bash
./scripts/create_proxmox_cloudinit_template.sh 192.168.1.5 root@192.168.1.5 local-lvm ubuntu-22.04-cloudinit https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

### Arguments

- proxmox_host: IP or hostname used as an informational value

- proxmox_user@host: SSH target (e.g. root@192.168.1.5)

- storage: Proxmox storage where the disk should be imported (e.g. `local-lvm`)

- template_name: Desired name for the template (e.g. `ubuntu-22.04-cloudinit`)

- image_url: Public URL of the cloud image (Ubuntu cloud image recommended)

- ssh_opts (optional): additional SSH flags, e.g. `-i ~/.ssh/id_rsa -o StrictHostKeyChecking=no`

### What the script does

- Downloads the specified cloud image on the Proxmox host

- Creates a temporary VM and imports the image as a disk

- Attaches the disk and sets basic VM options

- Converts the VM into a template and names it as requested

### Notes and troubleshooting

- The script expects `qm`, `pvesh`, `wget`, and `ssh` to be available on the Proxmox host.

- If you prefer to upload an ISO and use `ubuntu_iso` instead, set the following in `terraform/terraform.tfvars`:

```hcl
ubuntu_iso = "local:iso/ubuntu-22.04-server-amd64.iso"
```

- If Terraform still complains that the template wasn't found, verify in the Proxmox web UI that the template name matches exactly and that the Proxmox node/storage are correct.

- Questions or issues? Open an issue on the repo with the `proxmox` tag and include command output and Proxmox node details (avoid sharing secrets).
