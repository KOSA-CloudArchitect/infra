# Kubernetes Manifests - Review Analysis System

이 프로젝트는 EKS 클러스터에서 실행되는 리뷰 분석 시스템의 Kubernetes 매니페스트 파일들을 정리한 것입니다.

## 📁 폴더 구조

```
web-tier & cache-tier/
├── 01-foundation/     # 기반 인프라 (네임스페이스, 서비스계정, 시크릿)
├── 02-storage/        # 스토리지 (Redis, RDS)
├── 03-networking/     # 네트워킹 (ALB, Ingress, NetworkPolicy)
├── 04-applications/   # 애플리케이션 (Frontend, Backend, WebSocket)
├── 05-monitoring/     # 모니터링 (Prometheus, Grafana, AlertManager)
├── 06-logging/        # 로깅 (Fluent Bit)
├── 07-scripts/        # 배포 스크립트
└── 08-docs/           # 문서
```

## 🚀 빠른 시작

### 1. 기본 리소스 배포
```bash
kubectl apply -f 01-foundation/
```

### 2. 스토리지 배포
```bash
kubectl apply -f 02-storage/
```

### 3. 네트워킹 설정
```bash
# AWS Load Balancer Controller 설치 (Helm)
# 자세한 설치 방법은 03-networking/aws-load-balancer-controller/README.md 참조
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# IAM 역할 생성 및 정책 연결 후 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=YOUR_CLUSTER_NAME \
  --set region=ap-northeast-2 \
  --set vpcId=YOUR_VPC_ID

# 네트워크 정책 및 Ingress 배포
kubectl apply -f 03-networking/
```

### 4. 애플리케이션 배포
```bash
kubectl apply -f 04-applications/
```

### 5. 모니터링 배포
```bash
kubectl apply -f 05-monitoring/
```

### 6. 로깅 배포
```bash
kubectl apply -f 06-logging/
```

## 🔧 사전 요구사항

- Kubernetes 1.21+
- AWS EKS 클러스터
- Helm 3.x
- kubectl
- AWS CLI

## 📋 주요 구성 요소

### 애플리케이션
- **Frontend**: React 기반 웹 애플리케이션
- **Backend**: Node.js API 서버
- **WebSocket**: 실시간 통신 서버

### 데이터베이스
- **Redis**: 캐시 및 세션 저장소 (Master-Slave 구성)
- **RDS**: PostgreSQL 메인 데이터베이스

### 모니터링
- **Prometheus**: 메트릭 수집
- **Grafana**: 대시보드
- **AlertManager**: 알림 관리

### 로깅
- **Fluent Bit**: 로그 수집 및 전송

## 🌐 접근 URL

배포 완료 후 다음 URL로 접근할 수 있습니다:

- **메인 애플리케이션**: `http://YOUR_ALB_DNS_NAME`
- **모니터링**: `http://YOUR_MONITORING_ALB_DNS_NAME`
- **Grafana**: `http://YOUR_MONITORING_ALB_DNS_NAME/grafana`

## 📚 추가 문서

각 폴더의 README.md 파일에서 상세한 배포 가이드를 확인할 수 있습니다.

## 🆘 트러블슈팅

일반적인 문제들과 해결 방법은 각 폴더의 README.md를 참조하세요.

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.
