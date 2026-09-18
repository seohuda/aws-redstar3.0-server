# aws-redstar3.0-sever

> Running **Red Star OS 3.0 Server** (DPRK's Linux distro) on AWS EC2 with KVM nested virtualization.

AWS EC2에서 KVM nested virtualization으로 붉은별 3.0 서버(Red Star OS 3.0 Server, 32-bit)를 구동하는 프로젝트.

## 구성

- **호스트**: EC2 `c8i.xlarge` (Ubuntu 24.04, nested virt 활성화)
- **게스트**: 붉은별 3.0 서버 32-bit (2 vCPU, 2GB RAM, 40GB qcow2, e1000 NIC)
- **접속 방법**: SSH 터널을 통한 VNC (포트 5900), Nginx 리버스 프록시 (포트 80)
- **설치 미디어**: 2-ISO 구조 (boot.iso로 부팅 → install.iso로 패키지 설치)

## 사전 준비

- Terraform, AWS CLI 설정 완료
- 붉은별 3.0 서버 ISO 2장 (boot ISO + install ISO)을 로컬 다운로드 폴더에 준비
- VNC 클라이언트 (Remmina, TigerVNC 등)

## 설치

### 1. EC2 인프라 생성

Terraform으로 VPC, 보안그룹, EC2 인스턴스를 한번에 생성한다.
EC2가 뜨면 `user_data.sh`가 자동으로 KVM, libvirt, Nginx를 설치한다.

```bash
terraform -chdir=infra init
terraform -chdir=infra apply
```

apply가 끝나면 EC2 공인 IP와 SSH 명령이 출력된다.

### 2. ISO 업로드

로컬 다운로드 폴더에서 붉은별 ISO 2장을 자동으로 찾아 EC2에 SCP로 업로드한다.
SHA256 체크섬으로 이미 올라간 파일은 건너뛴다.

```bash
./scripts/upload-isos.sh
```

### 3. VM 생성

`virt-install`로 붉은별 VM을 만들고 boot.iso에서 부팅한다.
로컬에서 실행하면 자동으로 SSH를 통해 EC2에서 실행되고,
EC2 위에서 직접 실행해도 된다.

```bash
./scripts/create-redstar-vm.sh
```

### 4. VNC 접속

EC2의 VNC 포트(5900)는 localhost에만 바인딩되어 있으므로 SSH 터널이 필요하다.

```bash
# 터미널 1: 터널 열기
ssh -i <key> -N -L 5900:127.0.0.1:5900 ubuntu@<EC2_IP>

# 터미널 2: VNC 뷰어 접속
remmina -c vnc://127.0.0.1:5900
```

### 5. 붉은별 설치 진행

VNC로 접속하면 붉은별 부트로더가 뜬다. "붉은별 3.0 서버 설치"를 선택하고 진행한다.

설치 도중 **"두번째 설치원반을 넣어주십시오"** 라는 다이얼로그가 뜨면,
별도 터미널에서 ISO를 교체한 뒤 VNC 화면의 [확인]을 누른다.

```bash
./scripts/switch-to-install-iso.sh
```

### 6. 설치 완료 후 정리

설치가 끝나면 재부팅 전에 가상 CD-ROM에서 ISO를 빼야 한다.
안 빼면 매번 CD로 부팅을 시도한다.

```bash
./scripts/eject-redstar-iso.sh
```

VNC 화면에서 [재시동]을 누르면 qcow2 디스크에서 붉은별이 부팅된다.

## 파일 구조

```
.
├── infra/                          Terraform 인프라
│   ├── main.tf                     VPC, 보안그룹, SSH 키, EC2 정의
│   ├── variables.tf                리전, 인스턴스 타입, 볼륨 크기
│   ├── outputs.tf                  EC2 IP, SSH/VNC 접속 명령 출력
│   ├── versions.tf                 provider 버전 (aws, tls, local)
│   └── user_data.sh                EC2 초기화 (KVM, libvirt, Nginx 설치)
│
├── scripts/                        운영 스크립트
│   ├── upload-isos.sh              로컬 ISO 찾아서 EC2로 SCP (checksum 중복 방지)
│   ├── create-redstar-vm.sh        virt-install로 VM 생성
│   ├── switch-to-install-iso.sh    설치 중 두번째 ISO로 교체 (virsh change-media)
│   ├── switch-to-boot-iso.sh       boot ISO로 되돌리기
│   ├── eject-redstar-iso.sh        CD-ROM eject
│   └── keygen.sh                   붉은별 라이선스 키 생성 (dprkeygen 래퍼)
│
├── libvirt/
│   └── redstar-vm.xml.template     VM 도메인 XML 템플릿
│
├── nginx/
│   └── redstar.conf                외부 80포트 → 게스트 VM 웹서버 프록시
│
└── docs/
    ├── architecture.md             시스템 아키텍처
    ├── redstar_install_guide.md    설치 단계별 가이드
    └── troubleshooting.md          문제 해결
```