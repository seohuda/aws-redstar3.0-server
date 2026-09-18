# aws-redstar3.0-server

[![한국어](https://img.shields.io/badge/lang-한국어-red)](README.md)
[![English](https://img.shields.io/badge/lang-English-blue)](README.en.md)

> Running **Red Star OS 3.0 Server** (DPRK's Linux distro) on AWS EC2 with KVM nested virtualization.

## Overview

- **Host**: EC2 `c8i.xlarge` (Ubuntu 24.04, nested virtualization enabled)
- **Guest**: Red Star OS 3.0 Server, 32-bit (2 vCPU, 2GB RAM, 40GB qcow2, e1000 NIC)
- **Access**: VNC via SSH tunnel (port 5900), Nginx reverse proxy (port 80)
- **Install media**: 2-ISO setup (boot.iso for bootloader → install.iso for packages)

## Prerequisites

- Terraform and AWS CLI configured
- Two Red Star OS 3.0 Server ISOs (boot + install) in your local Downloads folder
- A VNC client (Remmina, TigerVNC, etc.)

## Installation

### 1. Create EC2 infrastructure

Terraform provisions VPC, security group, and an EC2 instance in one go.
Once the instance starts, `user_data.sh` automatically installs KVM, libvirt, and Nginx.

```bash
terraform -chdir=infra init
terraform -chdir=infra apply
```

The EC2 public IP and SSH command are printed after apply.

### 2. Upload ISOs

Finds the two Red Star ISOs in your local Downloads folder and uploads them to EC2 via SCP.
Skips already-uploaded files using SHA256 checksums.

```bash
./scripts/upload-isos.sh
```

### 3. Create VM

Creates the Red Star VM with `virt-install` and boots from boot.iso.
Run locally and it automatically delegates to EC2 over SSH.
Can also be run directly on the EC2 host.

```bash
./scripts/create-redstar-vm.sh
```

### 4. Connect via VNC

The VNC port (5900) is bound to localhost only, so you need an SSH tunnel.

```bash
# Terminal 1: open tunnel
ssh -i <key> -N -L 5900:127.0.0.1:5900 ubuntu@<EC2_IP>

# Terminal 2: launch VNC viewer
remmina -c vnc://127.0.0.1:5900
```

### 5. Install Red Star OS

The Red Star bootloader appears in VNC. Select the install option and proceed.

When the installer asks to **insert the second disc**, swap the ISO from a separate terminal, then click OK in VNC.

```bash
./scripts/switch-to-install-iso.sh
```

### 6. Post-install cleanup

Eject the virtual CD-ROM before rebooting. If you don't, it tries to boot from CD every time.

```bash
./scripts/eject-redstar-iso.sh
```

Click reboot in VNC. Red Star OS boots from the qcow2 disk.

## Project structure

```
.
├── infra/                          Terraform infrastructure
│   ├── main.tf                     VPC, security group, SSH key, EC2
│   ├── variables.tf                Region, instance type, volume size
│   ├── outputs.tf                  EC2 IP, SSH/VNC connection commands
│   ├── versions.tf                 Provider versions (aws, tls, local)
│   └── user_data.sh                Host bootstrap (KVM, libvirt, Nginx)
│
├── scripts/                        Operational scripts
│   ├── upload-isos.sh              Find and upload ISOs via SCP (checksum dedup)
│   ├── create-redstar-vm.sh        Provision VM with virt-install
│   ├── switch-to-install-iso.sh    Hot-swap to install ISO (virsh change-media)
│   ├── switch-to-boot-iso.sh       Swap back to boot ISO
│   ├── eject-redstar-iso.sh        Eject CD-ROM
│   └── keygen.sh                   Red Star license key generator (dprkeygen wrapper)
│
├── libvirt/
│   └── redstar-vm.xml.template     VM domain XML template
│
├── nginx/
│   └── redstar.conf                Reverse proxy: port 80 → guest VM web server
│
└── docs/
    ├── architecture.md             System architecture
    ├── redstar_install_guide.md    Step-by-step install guide
    └── troubleshooting.md          Troubleshooting
```
