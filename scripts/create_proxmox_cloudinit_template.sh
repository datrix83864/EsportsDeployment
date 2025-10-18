#!/usr/bin/env bash
set -euo pipefail

# create_proxmox_cloudinit_template.sh
# Create a Proxmox cloud-init template from an Ubuntu cloud image.
# This script SSHes to the Proxmox host, downloads the cloud image, imports
# it as a VM disk, and converts the VM to a template.
#
# Usage:
#   ./scripts/create_proxmox_cloudinit_template.sh <proxmox_host> <proxmox_user> <storage> <template_name> <image_url> [ssh_opts]
# Example:
#   ./scripts/create_proxmox_cloudinit_template.sh 192.168.1.5 root@pve.local local-lvm ubuntu-22.04-cloudinit https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <proxmox_host> <proxmox_user@host> <storage> <template_name> <image_url> [ssh_opts]"
  echo "Example: $0 192.168.1.5 root@192.168.1.5 local-lvm ubuntu-22.04-cloudinit https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  exit 2
fi

PROXMOX_HOST=$1
PROXMOX_SSH_TARGET=$2
STORAGE=$3
TEMPLATE_NAME=$4
IMAGE_URL=$5
shift 5
SSH_OPTS="$*"

# This script requires that you have SSH access to the Proxmox host as the provided user
# and that the `qm` and `pvesh` utilities exist on the remote host (they do on standard Proxmox installs).

echo "Creating Proxmox cloud-init template '${TEMPLATE_NAME}' on ${PROXMOX_HOST} (storage: ${STORAGE})"

ssh ${SSH_OPTS} "${PROXMOX_SSH_TARGET}" bash -s <<'REMOTE'
set -euo pipefail

STORAGE="${STORAGE}"
TEMPLATE_NAME="${TEMPLATE_NAME}"
IMAGE_URL="${IMAGE_URL}"

# Acquire a new VMID from the cluster
VMID=$(pvesh get /cluster/nextid)
TMPDIR="/var/tmp/cloudimg-${VMID}"
mkdir -p "${TMPDIR}"
cd "${TMPDIR}"

IMAGE_FILE=$(basename "${IMAGE_URL}")
if [[ ! -f "${IMAGE_FILE}" ]]; then
  echo "Downloading ${IMAGE_URL} to ${TMPDIR}/${IMAGE_FILE}..."
  wget -q --show-progress -O "${IMAGE_FILE}" "${IMAGE_URL}"
else
  echo "Image already present: ${IMAGE_FILE}"
fi

echo "Creating temporary VM ${VMID}..."
# Minimal VM so we can import disk; adjust memory/cores if needed
qm create ${VMID} --name temp-import-${VMID} --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 || true

echo "Importing disk into storage '${STORAGE}'..."
qm importdisk ${VMID} "${IMAGE_FILE}" ${STORAGE}

# Assuming imported disk is named vm-<VMID>-disk-0 on the storage
DISK_REF="${STORAGE}:vm-${VMID}-disk-0"

echo "Attaching disk ${DISK_REF} as scsi0 and enabling cloud-init configdrive..."
qm set ${VMID} --scsi0 ${DISK_REF}
qm set ${VMID} --boot order=scsi0
qm set ${VMID} --agent 1

echo "Converting VM ${VMID} to template named '${TEMPLATE_NAME}'..."
qm template ${VMID}
qm set ${VMID} --name ${TEMPLATE_NAME} || true

echo "Template created: ${TEMPLATE_NAME} (VMID: ${VMID})"
echo "Cleaning up temporary files..."
rm -rf "${TMPDIR}" || true

REMOTE

echo "Done. You should now be able to use template name '${TEMPLATE_NAME}' in Terraform (template_name)."
echo "If you prefer using an ISO instead, set ubuntu_iso in terraform.tfvars to the ISO path (e.g. local:iso/ubuntu-22.04-server-amd64.iso)."

exit 0
