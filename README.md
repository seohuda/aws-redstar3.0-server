# aws-redstar3.0-sever

AWS EC2 위에서 KVM nested virtualization으로 붉은별 3.0 서버(Red Star OS 3.0 Server)를 돌리는 프로젝트.

## 구성

- **호스트**: EC2 `c8i.xlarge` (nested virt 활성화, Ubuntu)
- **게스트**: 붉은별 3.0 서버 (32-bit, 2 vCPU / 2GB RAM / 40GB qcow2)
- **접속**: VNC (SSH 터널 5900 포트), 웹은 Nginx 리버스 프록시 (80 포트)

## 설치 순서

```
1. terraform init/plan/apply    → EC2 생성 (user_data.sh가 KVM/Nginx 자동 설치)
2. ./scripts/upload-isos.sh     → boot.iso + install.iso EC2로 업로드
3. ./scripts/create-redstar-vm.sh → VM 생성 및 boot.iso로 부팅
4. SSH 터널 열기                  → ssh -i <key> -N -L 5900:127.0.0.1:5900 ubuntu@<IP>
5. VNC 접속 (127.0.0.1:5900)    → 붉은별 설치 시작
6. "두번째 원반" 요청 시          → ./scripts/switch-to-install-iso.sh 실행 후 [확인]
7. 설치 완료                     → ./scripts/eject-redstar-iso.sh 로 CD 빼기
8. 재부팅                        → qcow2에서 정상 부팅 확인
```

## 프로젝트 구조

```
infra/
  main.tf, variables.tf, outputs.tf, versions.tf   # Terraform (VPC, SG, EC2)
  user_data.sh                                      # 호스트 부트스트랩

scripts/
  upload-isos.sh          # ISO 업로드 (checksum 중복 방지)
  create-redstar-vm.sh    # VM 생성
  switch-to-install-iso.sh / switch-to-boot-iso.sh  # ISO 교체
  eject-redstar-iso.sh    # CD-ROM eject
  keygen.sh               # 붉은별 라이선스 키 계산

libvirt/
  redstar-vm.xml.template # VM 도메인 정의

nginx/
  redstar.conf            # 리버스 프록시 설정

docs/
  architecture.md, redstar_install_guide.md, troubleshooting.md
```

## .gitignore

ISO, qcow2, pem, tfstate 등 민감/대용량 파일은 전부 git 추적에서 제외됨.