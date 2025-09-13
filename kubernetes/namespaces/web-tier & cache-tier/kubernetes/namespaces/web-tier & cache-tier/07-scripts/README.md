# 07-Scripts (스크립트)

이 폴더에는 배포 및 관리용 스크립트들이 포함되어 있습니다.

## 파일 목록

### Shell Scripts (.sh)
- `deploy-basic-resources.sh` - 기본 리소스 배포
- `deploy-ingress-network.sh` - Ingress 및 네트워크 배포
- `deploy-logging-alerts.sh` - 로깅 및 알림 배포
- `deploy-manifests.sh` - 전체 매니페스트 배포
- `deploy-monitoring.sh` - 모니터링 배포
- `deploy-redis.sh` - Redis 배포
- `verify-basic-resources.ps1` - 기본 리소스 검증
- `verify-ingress-network.ps1` - Ingress 및 네트워크 검증

### PowerShell Scripts (.ps1)
- `deploy-basic-resources.ps1` - 기본 리소스 배포 (Windows)
- `deploy-ingress-network.ps1` - Ingress 및 네트워크 배포 (Windows)
- `deploy-manifests.ps1` - 전체 매니페스트 배포 (Windows)
- `deploy-redis.ps1` - Redis 배포 (Windows)

## 사용법

```bash
# 전체 배포
./deploy-manifests.sh

# 단계별 배포
./deploy-basic-resources.sh
./deploy-redis.sh
./deploy-ingress-network.sh
./deploy-monitoring.sh
```
