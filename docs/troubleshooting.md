# 트러블슈팅 및 장애 대처 가이드 (Troubleshooting)

## 1. CD-ROM 미디어 교체 (change-media) 오류

### 증상
`./scripts/switch-to-install-iso.sh` 실행 시 `error: Failed to change media on disk` 또는 `device is locked` 오류가 발생할 때.

### 해결 방법
1. 설치 프로그램이 CD-ROM을 마운트한 상태로 잠그고 있는 경우:
   ```bash
   ssh -i infra/redstar-key.pem ubuntu@<EC2_IP>
   sudo virsh change-media redstar-server hdc --eject --force
   sudo virsh change-media redstar-server hdc /var/lib/libvirt/images/redstar-install.iso --insert --force
   ```
2. VM의 실제 CD-ROM target 식별:
   ```bash
   sudo virsh domblklist redstar-server
   ```
   출력된 목록에서 타입이 cdrom인 타깃(예: `hdc`, `hdb`, `sda`)을 확인하고 교체 명령을 수행합니다.

---

## 2. VNC 콘솔 연결 실패 또는 검은 화면

### 증상
VNC 클라이언트에서 `127.0.0.1:5900` 접속 시 연결 거부 또는 검은 화면 표시.

### 점검 및 조치
1. SSH 터널이 정상 유지되고 있는지 확인:
   ```bash
   # 로컬 터미널에서 포트 리스닝 확인
   ss -tulpn | grep 5900
   ```
2. 호스트에서 VM의 VNC 포트 바인딩 확인:
   ```bash
   sudo virsh vncdisplay redstar-server
   # 출력 결과가 :0 이면 5900번 포트입니다.
   ```
3. VM이 일시 중지(Paused) 상태인지 점검:
   ```bash
   sudo virsh domstate redstar-server
   # paused 라면 다음 명령으로 재개:
   sudo virsh resume redstar-server
   ```

---

## 3. KVM 하드웨어 가속 활성화 확인

### 증상
VM 구동 속도가 지나치게 느리거나 QEMU TCG 에뮬레이션 경고가 뜰 때.

### 점검 명령 (EC2 호스트)
```bash
# 1. KVM 장치 파일 존재 여부
ls -la /dev/kvm

# 2. CPU VMX/SVM 플래그 점검
grep -E '(vmx|svm)' /proc/cpuinfo

# 3. KVM 모듈 적재 여부
lsmod | grep kvm
```
- 만약 `/dev/kvm` 권한 오류가 발생하면:
  ```bash
  sudo chmod 666 /dev/kvm
  sudo usermod -aG kvm,libvirt ubuntu
  ```

---

## 4. Red Star VM 네트워크 IP 미할당

### 증상
설치 완료 후 VM이 인터넷에 연결되지 않거나 호스트 Nginx에서 502 오류 지속.

### 점검 절차
1. libvirt 기본 네트워크 동작 확인:
   ```bash
   sudo virsh net-list --all
   sudo virsh net-start default
   sudo virsh net-autostart default
   ```
2. VM에 할당된 DHCP 임대 IP 확인:
   ```bash
   sudo virsh net-dhcp-leases default
   ```
3. 확인된 IP를 `/etc/nginx/sites-available/redstar.conf`의 `proxy_pass` 주소에 반영하고 nginx reload:
   ```bash
   sudo systemctl reload nginx
   ```
