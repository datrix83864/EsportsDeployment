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

ssh ${SSH_OPTS} "${PROXMOX_SSH_TARGET}" bash -s "${STORAGE}" "${TEMPLATE_NAME}" "${IMAGE_URL}" <<'REMOTE'
set -euo pipefail

STORAGE="$1"
TEMPLATE_NAME="$2"
IMAGE_URL="$3"

# Acquire a new VMID from the cluster
VMID=$(pvesh get /cluster/nextid)
TMPDIR="/var/tmp/cloudimg-${VMID}"
mkdir -p "${TMPDIR}"
cd "${TMPDIR}"

IMAGE_FILE=$(basename "${IMAGE_URL}")
CHECKSUM_FILE="${IMAGE_FILE}.sha256"

# Download image if not present
if [[ ! -f "${IMAGE_FILE}" ]]; then
  echo "Downloading ${IMAGE_URL} to ${TMPDIR}/${IMAGE_FILE}..."
  if ! wget -q --show-progress -O "${IMAGE_FILE}" "${IMAGE_URL}"; then
    echo "ERROR: Failed to download cloud image from ${IMAGE_URL}"
    exit 1
  fi
else
  echo "Image already present: ${IMAGE_FILE}"
fi

# Download and verify checksum if available
CHECKSUM_URL="${IMAGE_URL%/*}/SHA256SUMS"
echo "Attempting to download checksums from ${CHECKSUM_URL}..."
if wget -q -O "${CHECKSUM_FILE}.tmp" "${CHECKSUM_URL}" 2>/dev/null; then
  # Extract checksum for our specific file
  EXPECTED_CHECKSUM=$(grep "$(basename ${IMAGE_FILE})" "${CHECKSUM_FILE}.tmp" | awk '{print $1}')
  if [[ -n "${EXPECTED_CHECKSUM}" ]]; then
    echo "Verifying image integrity..."
    ACTUAL_CHECKSUM=$(sha256sum "${IMAGE_FILE}" | awk '{print $1}')
    if [[ "${ACTUAL_CHECKSUM}" != "${EXPECTED_CHECKSUM}" ]]; then
      echo "ERROR: Checksum mismatch! Image may be corrupted."
      echo "  Expected: ${EXPECTED_CHECKSUM}"
      echo "  Got:      ${ACTUAL_CHECKSUM}"
      echo "Removing corrupted file and retrying download..."
      rm -f "${IMAGE_FILE}"
      if ! wget -q --show-progress -O "${IMAGE_FILE}" "${IMAGE_URL}"; then
        echo "ERROR: Failed to re-download cloud image"
        exit 1
      fi
      # Re-verify
      ACTUAL_CHECKSUM=$(sha256sum "${IMAGE_FILE}" | awk '{print $1}')
      if [[ "${ACTUAL_CHECKSUM}" != "${EXPECTED_CHECKSUM}" ]]; then
        echo "ERROR: Checksum still incorrect after re-download. Image source may be corrupted."
        exit 1
      fi
    fi
    echo "✓ Image checksum verified successfully"
  else
    echo "WARNING: Could not find checksum for ${IMAGE_FILE} in SHA256SUMS file"
  fi
  rm -f "${CHECKSUM_FILE}.tmp"
else
  echo "WARNING: Could not download checksums. Skipping verification."
fi

# Basic file validation - check if it's a valid image format
echo "Validating image file format..."
FILE_TYPE=$(file "${IMAGE_FILE}" 2>/dev/null || echo "unknown")
if [[ "${FILE_TYPE}" != *"QCOW"* ]] && [[ "${FILE_TYPE}" != *"disk image"* ]] && [[ "${FILE_TYPE}" != *"boot sector"* ]]; then
  echo "WARNING: File may not be a valid disk image. Type detected: ${FILE_TYPE}"
  echo "Proceeding anyway, but this may cause boot issues..."
fi

# Check file size - cloud images should typically be > 200MB
FILE_SIZE=$(stat -c%s "${IMAGE_FILE}" 2>/dev/null || stat -f%z "${IMAGE_FILE}" 2>/dev/null || echo "0")
if [[ "${FILE_SIZE}" -lt 209715200 ]]; then
  echo "WARNING: Image file seems too small ($(numfmt --to=iec-i --suffix=B ${FILE_SIZE} 2>/dev/null || echo ${FILE_SIZE} bytes))"
  echo "This may indicate an incomplete download or corrupted file."
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
