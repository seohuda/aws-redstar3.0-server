#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: scripts/switch-to-boot-iso.sh
# Purpose: Dynamically detect CD-ROM target from VM XML and switch media
#          back to redstar-boot.iso.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VM_NAME="redstar-server"
BOOT_ISO="/var/lib/libvirt/images/redstar-boot.iso"

run_on_host() {
  echo "=== Switching VM '${VM_NAME}' media to Boot ISO ==="

  if ! virsh dominfo "${VM_NAME}" >/dev/null 2>&1; then
    echo "ERROR: VM '${VM_NAME}' is not defined in libvirt."
    exit 1
  fi

  if [ ! -f "${BOOT_ISO}" ]; then
    echo "ERROR: Boot ISO not found at ${BOOT_ISO}."
    exit 1
  fi

  TARGET=""
  if which xmllint >/dev/null 2>&1; then
    TARGET="$(virsh dumpxml "${VM_NAME}" 2>/dev/null | xmllint --xpath "string(//disk[@device='cdrom']/target/@dev)" - 2>/dev/null || true)"
  fi

  if [ -z "${TARGET}" ]; then
    TARGET="$(virsh dumpxml "${VM_NAME}" 2>/dev/null | awk '/<disk [^>]*device=.cdrom./,/<\/disk>/' | sed -n 's/.*<target dev=.\([a-z0-9]*\).*/\1/p' | head -n 1)"
  fi

  if [ -z "${TARGET}" ]; then
    TARGET="hdc"
    echo "Notice: Could not parse XML for CD-ROM target dev, defaulting to '${TARGET}'."
  else
    echo "Detected CD-ROM target device from VM XML: '${TARGET}'"
  fi

  echo "Ejecting current media from '${TARGET}' (if present)..."
  virsh change-media "${VM_NAME}" "${TARGET}" --eject --force 2>/dev/null || true

  echo "Inserting Boot ISO (${BOOT_ISO}) into '${TARGET}'..."
  virsh change-media "${VM_NAME}" "${TARGET}" "${BOOT_ISO}" --insert --force

  echo "=== Successfully inserted Boot ISO ==="
  echo "Current media status for '${TARGET}':"
  virsh domblklist "${VM_NAME}" | grep "${TARGET}" || true
}

# Determine if running locally or remotely
if [ -e /etc/os-release ] && grep -qi "ubuntu" /etc/os-release && which virsh >/dev/null 2>&1; then
  run_on_host
else
  echo "Running from local machine. Connecting to EC2 host..."
  EC2_IP="$(terraform -chdir="${PROJECT_ROOT}/infra" output -raw public_ip 2>/dev/null || true)"
  if [ -z "${EC2_IP}" ] || [ "${EC2_IP}" = "No outputs found" ]; then
    echo "ERROR: Could not retrieve EC2 public IP from Terraform."
    exit 1
  fi

  if [ -n "${SSH_PRIVATE_KEY:-}" ] && [ -f "${SSH_PRIVATE_KEY}" ]; then
    SSH_KEY="${SSH_PRIVATE_KEY}"
  elif [ -f "${PROJECT_ROOT}/infra/redstar-key.pem" ]; then
    SSH_KEY="${PROJECT_ROOT}/infra/redstar-key.pem"
  elif [ -f "${HOME}/.ssh/redstar-key.pem" ]; then
    SSH_KEY="${HOME}/.ssh/redstar-key.pem"
  else
    echo "ERROR: SSH private key not found!"
    exit 1
  fi
  chmod 600 "${SSH_KEY}" 2>/dev/null || true

  SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  scp "${SSH_OPTS[@]}" "${BASH_SOURCE[0]}" ubuntu@"${EC2_IP}":/tmp/switch-to-boot-iso.sh
  ssh "${SSH_OPTS[@]}" ubuntu@"${EC2_IP}" "chmod +x /tmp/switch-to-boot-iso.sh && sudo /tmp/switch-to-boot-iso.sh"
fi
