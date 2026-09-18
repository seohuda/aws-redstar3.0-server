#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: scripts/create-redstar-vm.sh
# Purpose: Provision the Red Star OS 3.0 Server KVM virtual machine.
# Supports execution from both local machine (via SSH) and directly on EC2 host.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Function to run VM creation logic locally on the host
run_on_host() {
  echo "=== Running Red Star VM Creation on Host ==="

  VM_NAME="redstar-server"
  BOOT_ISO="/var/lib/libvirt/images/redstar-boot.iso"
  INSTALL_ISO="/var/lib/libvirt/images/redstar-install.iso"
  DISK_PATH="/var/lib/libvirt/images/redstar-server.qcow2"
  DISK_SIZE=40 # GB
  RAM_MB=2048
  VCPUS=2

  # Check ISO existence
  if [ ! -f "${BOOT_ISO}" ]; then
    echo "ERROR: Boot ISO not found at ${BOOT_ISO}."
    echo "Please run ./scripts/upload-isos.sh first."
    exit 1
  fi

  if [ ! -f "${INSTALL_ISO}" ]; then
    echo "ERROR: Install ISO not found at ${INSTALL_ISO}."
    echo "Please run ./scripts/upload-isos.sh first."
    exit 1
  fi

  # Check if VM already exists
  if virsh dominfo "${VM_NAME}" >/dev/null 2>&1; then
    STATE="$(virsh domstate "${VM_NAME}" 2>/dev/null || echo "unknown")"
    echo "VM '${VM_NAME}' already exists (Current state: ${STATE})."
    echo "To view console, create an SSH tunnel and connect via VNC (port 5900)."
    echo "To destroy and recreate: sudo virsh destroy ${VM_NAME} && sudo virsh undefine ${VM_NAME} --remove-all-storage"
    exit 0
  fi

  # Detect virtualization type
  VIRT_TYPE="kvm"
  if [ ! -e /dev/kvm ]; then
    echo "WARNING: /dev/kvm not found! Falling back to QEMU emulation (TCG)..."
    VIRT_TYPE="qemu"
  else
    echo "Hardware KVM acceleration available (/dev/kvm)."
  fi

  # Ensure default network is active
  virsh net-start default 2>/dev/null || true
  virsh net-autostart default 2>/dev/null || true

  # Create qcow2 disk image if not exists
  if [ ! -f "${DISK_PATH}" ]; then
    echo "Creating ${DISK_SIZE}GB qcow2 disk at ${DISK_PATH}..."
    qemu-img create -f qcow2 "${DISK_PATH}" "${DISK_SIZE}G"
    LIBVIRT_USER="libvirt-qemu"
    LIBVIRT_GROUP="kvm"
    id -u "${LIBVIRT_USER}" >/dev/null 2>&1 || LIBVIRT_USER="root"
    getent group "${LIBVIRT_GROUP}" >/dev/null 2>&1 || LIBVIRT_GROUP="libvirt"
    chown "${LIBVIRT_USER}:${LIBVIRT_GROUP}" "${DISK_PATH}" 2>/dev/null || true
    chmod 660 "${DISK_PATH}"
  fi

  echo "Launching virt-install for '${VM_NAME}'..."
  virt-install \
    --name "${VM_NAME}" \
    --ram "${RAM_MB}" \
    --vcpus "${VCPUS}" \
    --virt-type "${VIRT_TYPE}" \
    --os-variant rhel6.0 \
    --disk path="${DISK_PATH}",format=qcow2,bus=virtio \
    --disk path="${BOOT_ISO}",device=cdrom,bus=ide,target=hdc \
    --network network=default,model=e1000 \
    --graphics vnc,listen=127.0.0.1,port=5900 \
    --video vga \
    --boot cdrom,hd,menu=on \
    --import \
    --noautoconsole

  echo "=== Red Star OS VM '${VM_NAME}' successfully created and started ==="
  echo "VM State:"
  virsh domstate "${VM_NAME}"
  echo "VNC Display:"
  virsh vncdisplay "${VM_NAME}"
}

# Determine if running locally or remotely
if [ -e /etc/os-release ] && grep -qi "ubuntu" /etc/os-release && which virsh >/dev/null 2>&1; then
  # Running directly on Ubuntu host
  run_on_host
else
  # Running on local development machine, delegate to EC2
  echo "Running from local machine. Connecting to EC2 host..."
  if [ ! -d "${PROJECT_ROOT}/infra" ]; then
    echo "ERROR: infra directory not found at ${PROJECT_ROOT}/infra"
    exit 1
  fi

  EC2_IP="$(terraform -chdir="${PROJECT_ROOT}/infra" output -raw public_ip 2>/dev/null || true)"
  if [ -z "${EC2_IP}" ] || [ "${EC2_IP}" = "No outputs found" ]; then
    echo "ERROR: Could not retrieve EC2 public IP from Terraform. Has 'terraform apply' been run?"
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

  echo "Uploading create script to EC2 host and executing..."
  scp "${SSH_OPTS[@]}" "${BASH_SOURCE[0]}" ubuntu@"${EC2_IP}":/tmp/create-redstar-vm.sh
  ssh "${SSH_OPTS[@]}" ubuntu@"${EC2_IP}" "chmod +x /tmp/create-redstar-vm.sh && sudo /tmp/create-redstar-vm.sh"
fi
