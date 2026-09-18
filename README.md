# aws-redstar3.0-sever

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

## 설치 순서

```
1. terraform -chdir=infra init && apply    EC2 생성 (user_data.sh가 KVM, Nginx 자동 설치)
2. ./scripts/upload-isos.sh               boot.iso, install.iso를 EC2에 업로드
3. ./scripts/create-redstar-vm.sh          VM 생성, boot.iso로 부팅
4. ssh -i <key> -N -L 5900:localhost:5900 ubuntu@<IP>   VNC 터널 열기
5. VNC로 127.0.0.1:5900 접속              붉은별 설치 시작
6. "두번째 원반" 요청 시                     ./scripts/switch-to-install-iso.sh 실행 후 확인
7. 설치 끝나면                              ./scripts/eject-redstar-iso.sh 로 CD 제거
8. 재부팅                                   qcow2에서 정상 부팅 확인
```

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

## 참고

- ISO, qcow2 디스크, SSH 키(pem), Terraform state는 `.gitignore`로 git에서 제외됨.
- VM은 libvirt NAT 네트워크(`192.168.122.0/24`)에서 격리 구동됨.