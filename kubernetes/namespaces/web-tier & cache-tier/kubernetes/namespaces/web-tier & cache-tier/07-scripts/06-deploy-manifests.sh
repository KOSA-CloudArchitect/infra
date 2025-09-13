#!/bin/bash

# EKS Migration - Kubernetes 매니페스트 배포 스크립트
# Task 3: Kubernetes 매니페스트 작성 및 배포

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 스크립트 시작
log_info "EKS Migration - Kubernetes 매니페스트 배포 시작"

# kubectl 연결 확인
log_info "kubectl 연결 상태 확인 중..."
if ! kubectl cluster-info &> /dev/null; then
    log_error "kubectl이 클러스터에 연결되지 않았습니다. EKS 클러스터 연결을 확인하세요."
    exit 1
fi

CLUSTER_NAME=$(kubectl config current-context)
log_success "클러스터 연결 확인: $CLUSTER_NAME"

# 1단계: 네임스페이스 생성
log_info "1단계: 네임스페이스 및 기본 리소스 생성 중..."
kubectl apply -f 01-namespaces.yaml
log_success "네임스페이스 생성 완료"

# 네임스페이스 생성 대기
log_info "네임스페이스 생성 대기 중..."
sleep 5

# 2단계: ConfigMap 및 Secret 생성
log_info "2단계: ConfigMap 및 Secret 리소스 생성 중..."
log_warning "주의: Secret 값들을 실제 환경에 맞게 수정해야 합니다!"

kubectl apply -f 03-configmaps-secrets.yaml
log_success "ConfigMap 및 Secret 생성 완료"

# 3단계: Frontend 배포
log_info "3단계: Frontend (Next.js) 배포 중..."
kubectl apply -f 04-frontend-deployment.yaml
log_success "Frontend 배포 완료"

# 4단계: Backend 배포
log_info "4단계: Backend 배포 중..."
kubectl apply -f 05-backend-deployment.yaml
log_success "Backend 배포 완료"

# 5단계: WebSocket 배포
log_info "5단계: WebSocket 서버 배포 중..."
kubectl apply -f 06-websocket-deployment.yaml
log_success "WebSocket 서버 배포 완료"

# 배포 상태 확인
log_info "배포 상태 확인 중..."
echo ""
log_info "네임스페이스 목록:"
kubectl get namespaces -l app.kubernetes.io/part-of=review-analysis-system

echo ""
log_info "web-tier 네임스페이스의 리소스:"
kubectl get all -n web-tier

echo ""
log_info "cache-tier 네임스페이스의 리소스:"
kubectl get all -n cache-tier

echo ""
log_info "ConfigMap 및 Secret 확인:"
kubectl get configmaps,secrets -n web-tier
kubectl get configmaps,secrets -n cache-tier

# Pod 상태 확인
log_info "Pod 상태 확인 중..."
echo ""
log_info "web-tier Pod 상태:"
kubectl get pods -n web-tier -o wide

# HPA 상태 확인
echo ""
log_info "HPA 상태 확인:"
kubectl get hpa -n web-tier

# 서비스 상태 확인
echo ""
log_info "서비스 상태 확인:"
kubectl get services -n web-tier

echo ""
log_success "Kubernetes 매니페스트 배포가 완료되었습니다!"

# 다음 단계 안내
echo ""
log_info "다음 단계:"
log_info "1. ECR에 컨테이너 이미지를 푸시하세요"
log_info "2. Secret 값들을 실제 환경에 맞게 업데이트하세요"
log_info "3. Redis 클러스터를 배포하세요"
log_info "4. Ingress 리소스를 생성하세요"
log_info "5. 모니터링 및 로깅을 설정하세요"

echo ""
log_info "유용한 명령어:"
log_info "- Pod 로그 확인: kubectl logs -f deployment/frontend-deployment -n web-tier"
log_info "- Pod 상태 모니터링: kubectl get pods -n web-tier -w"
log_info "- 서비스 포트 포워딩: kubectl port-forward service/frontend-service 3000:3000 -n web-tier"
log_info "- 리소스 삭제: kubectl delete -f ."

echo ""
log_success "배포 스크립트 실행 완료!"