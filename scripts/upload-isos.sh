#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: scripts/upload-isos.sh
# Purpose: Detect local Red Star OS 3.0 Server ISOs, verify checksums,
#          and upload them to the AWS EC2 KVM host via SCP.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== [1/6] Detecting Download Directory and ISO Files ==="

DOWNLOAD_DIR="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
if [ -z "${DOWNLOAD_DIR}" ] || [ ! -d "${DOWNLOAD_DIR}" ]; then
  DOWNLOAD_DIR="${HOME}/Downloads"
fi

echo "Download directory: ${DOWNLOAD_DIR}"

# 1. Primary candidate paths
BOOT_ISO="${DOWNLOAD_DIR}/redstar3.0_SERVER_boot.iso"
INSTALL_ISO="${DOWNLOAD_DIR}/redstar3.0_SERVER_rss3_32_key_gui_20131212.iso"

# 2. If primary candidates are not found, search with pattern matching
if [ ! -f "${BOOT_ISO}" ]; then
  echo "Primary boot ISO path not found. Searching for matching patterns in ${DOWNLOAD_DIR}..."
  mapfile -t BOOT_CANDIDATES < <(find "${DOWNLOAD_DIR}" -maxdepth 1 -type f -iname '*redstar*boot*.iso' 2>/dev/null)
  if [ ${#BOOT_CANDIDATES[@]} -eq 1 ]; then
    BOOT_ISO="${BOOT_CANDIDATES[0]}"
    echo "Found Boot ISO via pattern search: ${BOOT_ISO}"
  elif [ ${#BOOT_CANDIDATES[@]} -gt 1 ]; then
    echo "ERROR: Multiple Boot ISO candidates found. Please specify manually:"
    printf ' - %s\n' "${BOOT_CANDIDATES[@]}"
    exit 1
  fi
fi

if [ ! -f "${INSTALL_ISO}" ]; then
  echo "Primary install ISO path not found. Searching for matching patterns in ${DOWNLOAD_DIR}..."
  mapfile -t INSTALL_CANDIDATES < <(find "${DOWNLOAD_DIR}" -maxdepth 1 -type f -iname '*rss3*32*key*gui*.iso' 2>/dev/null)
  if [ ${#INSTALL_CANDIDATES[@]} -eq 1 ]; then
    INSTALL_ISO="${INSTALL_CANDIDATES[0]}"
    echo "Found Install ISO via pattern search: ${INSTALL_ISO}"
  elif [ ${#INSTALL_CANDIDATES[@]} -gt 1 ]; then
    echo "ERROR: Multiple Install ISO candidates found. Please specify manually:"
    printf ' - %s\n' "${INSTALL_CANDIDATES[@]}"
    exit 1
  fi
fi

# 3. Validate existence
MISSING=0
if [ ! -f "${BOOT_ISO}" ]; then
  echo "ERROR: Boot ISO not found! Expected redstar3.0_SERVER_boot.iso in ${DOWNLOAD_DIR}"
  MISSING=1
else
  echo " [OK] Boot ISO found:    ${BOOT_ISO} ($(du -h "${BOOT_ISO}" | cut -f1))"
fi

if [ ! -f "${INSTALL_ISO}" ]; then
  echo "ERROR: Install ISO not found! Expected redstar3.0_SERVER_rss3_32_key_gui_20131212.iso in ${DOWNLOAD_DIR}"
  MISSING=1
else
  echo " [OK] Install ISO found: ${INSTALL_ISO} ($(du -h "${INSTALL_ISO}" | cut -f1))"
fi

if [ "${MISSING}" -ne 0 ]; then
  echo "ABORT: Please place the required ISOs in ${DOWNLOAD_DIR}."
  exit 1
fi

echo "=== [2/6] Calculating Local SHA256 Checksums ==="
LOCAL_BOOT_SHA="$(sha256sum "${BOOT_ISO}" | awk '{print $1}')"
LOCAL_INSTALL_SHA="$(sha256sum "${INSTALL_ISO}" | awk '{print $1}')"
echo "Local Boot ISO SHA256:    ${LOCAL_BOOT_SHA}"
echo "Local Install ISO SHA256: ${LOCAL_INSTALL_SHA}"

echo "=== [3/6] Fetching EC2 Information from Terraform ==="
if [ ! -d "${PROJECT_ROOT}/infra" ]; then
  echo "ERROR: infra directory not found at ${PROJECT_ROOT}/infra"
  exit 1
fi

EC2_IP="$(terraform -chdir="${PROJECT_ROOT}/infra" output -raw public_ip 2>/dev/null || true)"
if [ -z "${EC2_IP}" ] || [ "${EC2_IP}" = "No outputs found" ]; then
  echo "ERROR: Could not retrieve EC2 public IP from Terraform. Has 'terraform apply' been run?"
  exit 1
fi
echo "Target EC2 Public IP: ${EC2_IP}"

# Determine SSH Key path
if [ -n "${SSH_PRIVATE_KEY:-}" ] && [ -f "${SSH_PRIVATE_KEY}" ]; then
  SSH_KEY="${SSH_PRIVATE_KEY}"
elif [ -f "${PROJECT_ROOT}/infra/redstar-key.pem" ]; then
  SSH_KEY="${PROJECT_ROOT}/infra/redstar-key.pem"
elif [ -f "${HOME}/.ssh/redstar-key.pem" ]; then
  SSH_KEY="${HOME}/.ssh/redstar-key.pem"
else
  echo "ERROR: SSH private key not found! Expected at ${PROJECT_ROOT}/infra/redstar-key.pem or via SSH_PRIVATE_KEY env var."
  exit 1
fi
chmod 600 "${SSH_KEY}" 2>/dev/null || true
echo "Using SSH Key: ${SSH_KEY}"

SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

echo "=== [4/6] Checking Existing Remote ISO Checksums (Skip if identical) ==="
REMOTE_CHECK_CMD="
  BOOT_SHA=\"\"
  INSTALL_SHA=\"\"
  [ -f /var/lib/libvirt/images/redstar-boot.iso ] && BOOT_SHA=\$(sha256sum /var/lib/libvirt/images/redstar-boot.iso | awk '{print \$1}')
  [ -f /var/lib/libvirt/images/redstar-install.iso ] && INSTALL_SHA=\$(sha256sum /var/lib/libvirt/images/redstar-install.iso | awk '{print \$1}')
  echo \"\${BOOT_SHA}:\${INSTALL_SHA}\"
"

REMOTE_SHAS="$(ssh "${SSH_OPTS[@]}" ubuntu@"${EC2_IP}" "${REMOTE_CHECK_CMD}" 2>/dev/null || true)"
REMOTE_BOOT_SHA="$(echo "${REMOTE_SHAS}" | cut -d':' -f1)"
REMOTE_INSTALL_SHA="$(echo "${REMOTE_SHAS}" | cut -d':' -f2)"

SKIP_BOOT=false
SKIP_INSTALL=false

if [ "${LOCAL_BOOT_SHA}" = "${REMOTE_BOOT_SHA}" ]; then
  echo " [SKIP] Boot ISO already exists on remote with matching SHA256."
  SKIP_BOOT=true
fi

if [ "${LOCAL_INSTALL_SHA}" = "${REMOTE_INSTALL_SHA}" ]; then
  echo " [SKIP] Install ISO already exists on remote with matching SHA256."
  SKIP_INSTALL=true
fi

echo "=== [5/6] Uploading ISOs to EC2 Host ==="
BOOT_BASENAME="$(basename "${BOOT_ISO}")"
INSTALL_BASENAME="$(basename "${INSTALL_ISO}")"

if [ "${SKIP_BOOT}" = false ]; then
  echo "Uploading ${BOOT_BASENAME}..."
  scp "${SSH_OPTS[@]}" "${BOOT_ISO}" ubuntu@"${EC2_IP}":"/tmp/${BOOT_BASENAME}"
  ssh "${SSH_OPTS[@]}" ubuntu@"${EC2_IP}" "sudo mv '/tmp/${BOOT_BASENAME}' /var/lib/libvirt/images/redstar-boot.iso"
fi

if [ "${SKIP_INSTALL}" = false ]; then
  echo "Uploading ${INSTALL_BASENAME} (approx 850MB, please wait)..."
  scp "${SSH_OPTS[@]}" "${INSTALL_ISO}" ubuntu@"${EC2_IP}":"/tmp/${INSTALL_BASENAME}"
  ssh "${SSH_OPTS[@]}" ubuntu@"${EC2_IP}" "sudo mv '/tmp/${INSTALL_BASENAME}' /var/lib/libvirt/images/redstar-install.iso"
fi

echo "=== [6/6] Setting Ownership and Verifying Remote Checksums ==="
REMOTE_FINALIZE_CMD="
  LIBVIRT_USER='libvirt-qemu'
  LIBVIRT_GROUP='kvm'
  id -u '\${LIBVIRT_USER}' >/dev/null 2>&1 || LIBVIRT_USER='root'
  getent group '\${LIBVIRT_GROUP}' >/dev/null 2>&1 || LIBVIRT_GROUP='libvirt'

  sudo chown \"\${LIBVIRT_USER}:\${LIBVIRT_GROUP}\" \
    /var/lib/libvirt/images/redstar-boot.iso \
    /var/lib/libvirt/images/redstar-install.iso 2>/dev/null || true
  sudo chmod 644 \
    /var/lib/libvirt/images/redstar-boot.iso \
    /var/lib/libvirt/images/redstar-install.iso

  echo 'Remote ISO Checksums:'
  sha256sum \
    /var/lib/libvirt/images/redstar-boot.iso \
    /var/lib/libvirt/images/redstar-install.iso
"

ssh "${SSH_OPTS[@]}" ubuntu@"${EC2_IP}" "${REMOTE_FINALIZE_CMD}"

echo "=== ISO Upload Process Completed Successfully ==="
