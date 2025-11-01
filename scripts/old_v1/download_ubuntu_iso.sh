#!/usr/bin/env bash
set -euo pipefail

# download_ubuntu_iso.sh
# Download Ubuntu Server ISO and upload it to Proxmox storage for VM installation.
# This provides an alternative to cloud-init images when those fail or for manual installations.
#
# Usage:
#   ./scripts/download_ubuntu_iso.sh <proxmox_host> <proxmox_user@host> <iso_storage> <ubuntu_version> [ssh_opts]
# Example:
#   ./scripts/download_ubuntu_iso.sh 192.168.1.5 root@192.168.1.5 local 22.04 "-o StrictHostKeyChecking=no"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <proxmox_host> <proxmox_user@host> <iso_storage> <ubuntu_version> [ssh_opts]"
  echo "Example: $0 192.168.1.5 root@192.168.1.5 local 22.04"
  echo ""
  echo "Common Ubuntu versions: 22.04, 24.04, 20.04"
  echo "ISO storage is typically 'local' for most Proxmox setups"
  exit 2
fi

PROXMOX_HOST=$1
PROXMOX_SSH_TARGET=$2
ISO_STORAGE=$3
UBUNTU_VERSION=$4
shift 4
SSH_OPTS="${*:-}"

# Map version to release name
case "${UBUNTU_VERSION}" in
  24.04|24.04.*)
    RELEASE_NAME="noble"
    FULL_VERSION="24.04.1"
    ;;
  22.04|22.04.*)
    RELEASE_NAME="jammy"
    FULL_VERSION="22.04.5"
    ;;
  20.04|20.04.*)
    RELEASE_NAME="focal"
    FULL_VERSION="20.04.6"
    ;;
  *)
    echo "ERROR: Unsupported Ubuntu version: ${UBUNTU_VERSION}"
    echo "Supported versions: 20.04, 22.04, 24.04"
    exit 1
    ;;
esac

ISO_FILENAME="ubuntu-${FULL_VERSION}-live-server-amd64.iso"
ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/${ISO_FILENAME}"
CHECKSUM_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/SHA256SUMS"

echo "======================================"
echo "Ubuntu Server ISO Download & Upload"
echo "======================================"
echo "Version:       Ubuntu ${UBUNTU_VERSION} (${RELEASE_NAME})"
echo "ISO File:      ${ISO_FILENAME}"
echo "Proxmox Host:  ${PROXMOX_HOST}"
echo "ISO Storage:   ${ISO_STORAGE}"
echo "======================================"
echo ""

# Check if ISO already exists on Proxmox
echo "Checking if ISO already exists on Proxmox..."
if ssh ${SSH_OPTS} "${PROXMOX_SSH_TARGET}" "test -f /var/lib/vz/template/iso/${ISO_FILENAME}" 2>/dev/null; then
  echo "✓ ISO already exists on Proxmox: ${ISO_STORAGE}:iso/${ISO_FILENAME}"
  echo ""
  echo "You can use this in your terraform.tfvars:"
  echo "ubuntu_iso = \"${ISO_STORAGE}:iso/${ISO_FILENAME}\""
  exit 0
fi

echo "ISO not found on Proxmox. Proceeding with download and upload..."
echo ""

# Create temporary directory for download
TMPDIR=$(mktemp -d -t ubuntu-iso-XXXXXX)
trap "rm -rf ${TMPDIR}" EXIT

cd "${TMPDIR}"

# Download checksum file
echo "[1/5] Downloading checksums..."
if ! wget -q --show-progress "${CHECKSUM_URL}"; then
  echo "ERROR: Failed to download checksums from ${CHECKSUM_URL}"
  exit 1
fi

# Extract expected checksum for our ISO
EXPECTED_CHECKSUM=$(grep "${ISO_FILENAME}" SHA256SUMS | awk '{print $1}')
if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
  echo "ERROR: Could not find checksum for ${ISO_FILENAME} in SHA256SUMS"
  exit 1
fi
echo "✓ Expected checksum: ${EXPECTED_CHECKSUM}"

# Download ISO
echo ""
echo "[2/5] Downloading Ubuntu Server ISO (this may take several minutes)..."
echo "Source: ${ISO_URL}"
if ! wget --show-progress "${ISO_URL}"; then
  echo "ERROR: Failed to download ISO from ${ISO_URL}"
  exit 1
fi

# Verify checksum
echo ""
echo "[3/5] Verifying ISO integrity..."
ACTUAL_CHECKSUM=$(sha256sum "${ISO_FILENAME}" | awk '{print $1}')
if [[ "${ACTUAL_CHECKSUM}" != "${EXPECTED_CHECKSUM}" ]]; then
  echo "ERROR: Checksum mismatch!"
  echo "  Expected: ${EXPECTED_CHECKSUM}"
  echo "  Got:      ${ACTUAL_CHECKSUM}"
  echo ""
  echo "The downloaded ISO is corrupted. Please retry."
  exit 1
fi
echo "✓ ISO checksum verified successfully"

# Upload to Proxmox
echo ""
echo "[4/5] Uploading ISO to Proxmox (${PROXMOX_HOST})..."
if ! scp ${SSH_OPTS} "${ISO_FILENAME}" "${PROXMOX_SSH_TARGET}:/var/lib/vz/template/iso/${ISO_FILENAME}"; then
  echo "ERROR: Failed to upload ISO to Proxmox"
  exit 1
fi
echo "✓ ISO uploaded successfully"

# Verify upload
echo ""
echo "[5/5] Verifying ISO on Proxmox..."
REMOTE_CHECKSUM=$(ssh ${SSH_OPTS} "${PROXMOX_SSH_TARGET}" "sha256sum /var/lib/vz/template/iso/${ISO_FILENAME}" | awk '{print $1}')
if [[ "${REMOTE_CHECKSUM}" != "${EXPECTED_CHECKSUM}" ]]; then
  echo "ERROR: Uploaded ISO checksum mismatch!"
  echo "  Expected: ${EXPECTED_CHECKSUM}"
  echo "  Got:      ${REMOTE_CHECKSUM}"
  exit 1
fi
echo "✓ Upload verified successfully"

echo ""
echo "======================================"
echo "SUCCESS!"
echo "======================================"
echo ""
echo "Ubuntu Server ISO is now available on Proxmox:"
echo "  Storage Path: ${ISO_STORAGE}:iso/${ISO_FILENAME}"
echo ""
echo "To use this ISO in Terraform, add to your terraform.tfvars:"
echo "  ubuntu_iso = \"${ISO_STORAGE}:iso/${ISO_FILENAME}\""
echo ""
echo "Or in config.yaml under proxmox section:"
echo "  ubuntu_iso: \"${ISO_STORAGE}:iso/${ISO_FILENAME}\""
echo ""
echo "NOTE: When using ISO instead of cloud-init templates, you may need to"
echo "      perform manual installation or use a preseed/autoinstall file."
echo "======================================"

exit 0
