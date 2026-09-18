#!/usr/bin/env bash
set -euo pipefail

# Output logging
exec > >(tee -a /var/log/user-data.log) 2>&1
echo "=== Starting Red Star OS Host Bootstrap ==="
date

# 1. Update and install required packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virtinst \
  libguestfs-tools \
  libxml2-utils \
  nginx \
  jq \
  curl \
  wget \
  htop \
  net-tools \
  iptables

# 2. Add ubuntu user to virtualization groups
usermod -aG libvirt,kvm ubuntu

# 3. Enable and start libvirtd
systemctl enable --now libvirtd

# 4. Verify KVM availability
if [ -e /dev/kvm ]; then
  echo "KVM acceleration is available at /dev/kvm"
  chmod 666 /dev/kvm
else
  echo "WARNING: /dev/kvm not found! Attempting modprobe..."
  modprobe kvm || true
  modprobe kvm_intel || true
fi

# 5. Ensure default libvirt network is running and autostarted
virsh net-start default 2>/dev/null || true
virsh net-autostart default 2>/dev/null || true

# 6. Prepare libvirt images directory with proper ownership
LIBVIRT_USER="libvirt-qemu"
LIBVIRT_GROUP="kvm"
if ! id -u "$LIBVIRT_USER" >/dev/null 2>&1; then
  LIBVIRT_USER="root"
fi
if ! getent group "$LIBVIRT_GROUP" >/dev/null 2>&1; then
  LIBVIRT_GROUP="libvirt"
fi

mkdir -p /var/lib/libvirt/images
chown -R "${LIBVIRT_USER}:${LIBVIRT_GROUP}" /var/lib/libvirt/images
chmod 775 /var/lib/libvirt/images

# 7. Configure Nginx reverse proxy for Red Star OS Server
# Red Star OS 3.0 Server guest IP will typically be assigned by libvirt DHCP (192.168.122.x)
cat <<'EOF' > /etc/nginx/sites-available/redstar.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    client_max_body_size 100M;

    location / {
        # Check if Red Star VM is running and proxy or fallback to status page
        proxy_pass http://192.168.122.100:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 30s;

        # Fallback to local status page if guest web server is not ready yet
        error_page 502 503 504 = @fallback;
    }

    location @fallback {
        default_type text/html;
        return 200 '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Red Star OS 3.0 Server - EC2 Gateway</title>
    <style>
        body { font-family: sans-serif; background: #0b1528; color: #fff; text-align: center; padding: 50px; }
        .card { background: #16243d; border-radius: 8px; padding: 30px; max-width: 600px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.5); }
        h1 { color: #e74c3c; }
        p { font-size: 16px; line-height: 1.6; color: #cbd5e1; }
        .badge { display: inline-block; padding: 5px 12px; border-radius: 4px; background: #2563eb; color: #fff; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>붉은별 3.0 서버 (Red Star OS 3.0 Server)</h1>
        <p><span class="badge">호스트 게이트웨이 정상 가동 중</span></p>
        <p>Red Star OS 가상 머신이 설치 중이거나 부팅 중입니다.<br>
        VNC 콘솔(SSH 터널 5900 포트)을 통해 설치를 완료하면 웹 서비스가 자동으로 연동됩니다.</p>
    </div>
</body>
</html>';
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/redstar.conf /etc/nginx/sites-enabled/redstar.conf
nginx -t && systemctl restart nginx

# 8. Signal bootstrap completion
touch /var/log/bootstrap-finished
echo "=== Red Star OS Host Bootstrap Completed Successfully ==="
date
