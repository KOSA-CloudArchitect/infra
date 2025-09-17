# 01-Foundation (기반 인프라)

이 폴더에는 Kubernetes 클러스터의 기본 인프라 구성 요소들이 포함되어 있습니다.

## 파일 목록

- `01-namespaces.yaml` - 네임스페이스 정의
- `02-service-accounts.yaml` - 서비스 계정 정의
- `03-configmaps-secrets.yaml` - ConfigMap과 Secret 정의
- `database-secret-rds.yaml` - RDS 데이터베이스 연결 정보
- `external-services-secret-updated.yaml` - 외부 서비스 연결 정보

## 배포 순서

1. 네임스페이스 생성
2. 서비스 계정 생성
3. ConfigMap과 Secret 생성
4. 데이터베이스 연결 정보 설정
