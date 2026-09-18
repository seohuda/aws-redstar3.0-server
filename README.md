# Red Star OS 3.0 Server on AWS EC2 (KVM Nested Virtualization)

AWS EC2의 하드웨어 중첩 가상화(Nested Virtualization)와 KVM/libvirt 하이퍼바이저를 활용하여 북한의 리눅스 배포판 **붉은별 3.0 서버 (Red Star OS 3.0 Server)** 가상 머신을 안정적으로 구축하고 운영할 수 있는 완전 자동화 인프라 프로젝트입니다.

---

## 📋 시스템 주요 사양

- **호스트 인스턴스**: AWS EC2 `c8i.xlarge` (4 vCPU, 8GB RAM, 최신 Intel Xeon)
  - `cpu_options { nested_virtualization = "enabled" }` 적용으로 `/dev/kvm` 하드웨어 가속 지원
- **게스트 가상 머신**: 붉은별 3.0 서버 (Red Star OS 3.0 Server, 32-bit i686)
  - 2 vCPU / 2GB RAM / 40GB qcow2 디스크 / Intel e1000 NIC / VGA 어댑터
- **미디어 아키텍처**: 2-ISO 구조 (초기 시동용 `boot.iso` + 패키지 데이터 `install.iso`)
- **보안 및 접속**:
  - VNC 콘솔: `127.0.0.1:5900` 로컬 바인딩 및 SSH 암호화 터널링
  - 웹 게이트웨이: 호스트 Nginx 리버스 프록시 (포트 80)

---

## 🚀 전체 설치 및 배포 절차 (14단계)

### 1. Terraform으로 AWS 생성
Terraform을 초기화하고 인프라 계획을 확인한 뒤 프로비저닝을 진행합니다.
```bash
terraform -chdir=infra init
terraform -chdir=infra plan
terraform -chdir=infra apply
```

### 2. Ubuntu host bootstrap
EC2 인스턴스가 시작되면 `user_data.sh`에 의해 KVM, libvirt, virtinst, Nginx 패키지가 자동 설치되고 가상화 환경이 준비됩니다.

### 3. 다운로드 폴더의 ISO 확인
로컬 PC의 다운로드 디렉터리에 필수 ISO 2장이 존재하는지 확인합니다.
```bash
ls -lh "$(xdg-user-dir DOWNLOAD)"
```
- `redstar3.0_SERVER_boot.iso` (부팅용 ISO)
- `redstar3.0_SERVER_rss3_32_key_gui_20131212.iso` (설치 패키지 ISO)

### 4. 두 ISO EC2 업로드
자동 탐색 및 업로드 스크립트를 실행합니다. (중복 업로드 방지 SHA256 체크섬 기능 내장)
```bash
./scripts/upload-isos.sh
```

### 5. Red Star VM 생성
가상 머신을 생성하고 부팅 ISO(`redstar-boot.iso`)를 마운트하여 시작합니다.
```bash
./scripts/create-redstar-vm.sh
```

### 6. SSH VNC tunnel 생성
EC2의 VNC 포트(5900)에 안전하게 접속하기 위해 로컬 PC에서 SSH 터널을 엽니다.
```bash
# Terraform output 명령 활용 또는 직접 입력
ssh -i infra/redstar-key.pem -N -L 5900:127.0.0.1:5900 ubuntu@<EC2_IP>
```

### 7. 로컬 VNC Viewer에서 접속
로컬 VNC 클라이언트(TigerVNC, RealVNC, Remmina 등)를 실행하여 다음 주소로 접속합니다.
```
127.0.0.1:5900
```

### 8. boot.iso로 installer 시작
VNC 콘솔에서 붉은별 운영체제 부트로더가 표시되면 **"붉은별 3.0 서버 설치"**를 선택하고 설치를 시작합니다.

### 9. installer가 실제 installation media를 요구하면 로컬 PC 또는 EC2에서 미디어 교체
설치 마법사 진행 중 **"두번째 설치원반을 넣어주십시오"** 다이얼로그가 표시되면 로컬 터미널(또는 EC2)에서 다음 스크립트를 실행합니다.
```bash
./scripts/switch-to-install-iso.sh
```
스크립트 실행 완료 후 VNC 화면의 **[확인]** 버튼을 누릅니다.

### 10. 설치 계속 진행
패키지 복사 및 설정 작업이 완료될 때까지 대기합니다.

### 11. 설치 완료
시스템 설치 완료 안내 화면이 표시됩니다.

### 12. ISO eject
재부팅 전에 가상 CD-ROM에서 미디어를 추출합니다.
```bash
./scripts/eject-redstar-iso.sh
```

### 13. VM reboot
VNC 화면에서 **[재시동]** 버튼을 클릭하여 시스템을 재부팅합니다.

### 14. qcow2에서 정상적으로 Red Star OS Server가 부팅되는지 확인
붉은별 3.0 서버가 qcow2 디스크로부터 정상적으로 부팅되는지 VNC 화면에서 확인합니다.

---

## 📂 프로젝트 구조

```
aws-redstar3.0-sever/
├── .gitignore                      # ISO, 가상 디스크, 비밀키, Terraform 상태 파일 추적 차단
├── README.md                       # 설치 및 운영 가이드
├── infra/                          # Terraform AWS 인프라 코드
│   ├── main.tf                     # VPC, SG, SSH Key, EC2 (Nested Virtualization)
│   ├── variables.tf                # 리전, 인스턴스 타입(c8i.xlarge), 볼륨 크기(80GB)
│   ├── outputs.tf                  # Public IP, SSH 접속 명령, VNC 터널 명령
│   ├── versions.tf                 # Provider 버전 (AWS >= 6.0, TLS, Local)
│   └── user_data.sh                # Ubuntu 호스트 KVM/Nginx 자동 부트스트랩
├── scripts/                        # 운영 및 관리 스크립트
│   ├── upload-isos.sh              # 로컬 ISO 탐색, Checksum 검증, SCP 업로드
│   ├── create-redstar-vm.sh        # Red Star OS 3.0 Server VM 프로비저닝
│   ├── switch-to-install-iso.sh    # Install ISO 미디어 교체 (virsh change-media)
│   ├── switch-to-boot-iso.sh       # Boot ISO 미디어 교체
│   └── eject-redstar-iso.sh        # CD-ROM 미디어 배출
├── libvirt/                        # KVM Libvirt 정의 템플릿
│   └── redstar-vm.xml.template     # Red Star OS 3.0 Server 도메인 XML
├── nginx/                          # 리버스 프록시 설정
│   └── redstar.conf                # 웹 트래픽 중계 및 게이트웨이 대기 화면
└── docs/                           # 상세 문서
    ├── architecture.md             # 시스템 아키텍처 및 다이어그램
    ├── redstar_install_guide.md    # GUI 단계별 설치 매뉴얼
    └── troubleshooting.md          # 오류 해결 및 트러블슈팅
```

---

## 🔒 보안 규칙 준수

- ISO 이미지(`*.iso`), 가상 머신 디스크(`*.qcow2`), SSH 개인키(`*.pem`, `*.key`), Terraform State(`*.tfstate`)는 `.gitignore`를 통해 Git 추적에서 원천 제외됩니다.
- Red Star OS 게스트 VM에는 AWS 자격 증명이 일체 전달되지 않으며, 격리된 가상 네트워크(NAT) 환경에서 안전하게 구동됩니다.