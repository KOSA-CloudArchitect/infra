#!/bin/bash
# EKS Migration - Monitoring Stack Deployment Script
# Task 6.1: 기본 모니터링 구성 배포

set -e

echo "🔧 KOSA EKS 모니터링 스택 배포 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수 정의
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

# kubectl 연결 확인
check_kubectl() {
    log_info "kubectl 연결 상태 확인 중..."
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl이 클러스터에 연결되지 않았습니다."
        log_info "다음 명령어로 EKS 클러스터에 연결하세요:"
        echo "aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-cluster"
        exit 1
    fi
    log_success "kubectl 연결 확인 완료"
}

# 네임스페이스 확인 및 생성
setup_namespaces() {
    log_info "네임스페이스 설정 중..."
    
    # monitoring 네임스페이스가 이미 존재하는지 확인
    if kubectl get namespace monitoring &> /dev/null; then
        log_warning "monitoring 네임스페이스가 이미 존재합니다."
    else
        log_info "네임스페이스 생성 중..."
        kubectl apply -f 01-namespaces.yaml
        log_success "네임스페이스 생성 완료"
    fi
}

# Prometheus 배포
deploy_prometheus() {
    log_info "Prometheus 배포 중..."
    kubectl apply -f 09-monitoring-prometheus.yaml
    
    # Prometheus Pod가 Ready 상태가 될 때까지 대기
    log_info "Prometheus Pod 시작 대기 중..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
    log_success "Prometheus 배포 완료"
}

# Redis Exporter 배포
deploy_redis_exporter() {
    log_info "Redis Exporter 배포 중..."
    
    # cache-tier 네임스페이스 확인
    if ! kubectl get namespace cache-tier &> /dev/null; then
        log_warning "cache-tier 네임스페이스가 존재하지 않습니다. Redis가 먼저 배포되어야 합니다."
        return 1
    fi
    
    kubectl apply -f 10-monitoring-redis-exporter.yaml
    
    # Redis Exporter Pod가 Ready 상태가 될 때까지 대기
    log_info "Redis Exporter Pod 시작 대기 중..."
    kubectl wait --for=condition=ready pod -l app=redis-exporter -n cache-tier --timeout=180s
    log_success "Redis Exporter 배포 완료"
}

# Grafana 배포
deploy_grafana() {
    log_info "Grafana 배포 중..."
    kubectl apply -f 11-monitoring-grafana.yaml
    
    # Grafana Pod가 Ready 상태가 될 때까지 대기
    log_info "Grafana Pod 시작 대기 중..."
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
    log_success "Grafana 배포 완료"
}

# 서비스 상태 확인
check_services() {
    log_info "배포된 서비스 상태 확인 중..."
    
    echo ""
    echo "=== Monitoring Namespace Pods ==="
    kubectl get pods -n monitoring -o wide
    
    echo ""
    echo "=== Monitoring Services ==="
    kubectl get services -n monitoring
    
    echo ""
    echo "=== Redis Exporter (cache-tier) ==="
    kubectl get pods -n cache-tier -l app=redis-exporter -o wide
    kubectl get services -n cache-tier -l app=redis-exporter
}

# 포트 포워딩 설정 안내
setup_port_forwarding() {
    log_info "포트 포워딩 설정 안내:"
    echo ""
    echo "다음 명령어들을 사용하여 모니터링 대시보드에 접근할 수 있습니다:"
    echo ""
    echo "# Prometheus (포트 9090)"
    echo "kubectl port-forward -n monitoring svc/prometheus-service 9090:9090"
    echo ""
    echo "# Grafana (포트 3000)"
    echo "kubectl port-forward -n monitoring svc/grafana-service 3000:3000"
    echo ""
    echo "Grafana 로그인 정보:"
    echo "  - 사용자명: admin"
    echo "  - 비밀번호: kosa-admin-2024"
    echo ""
}

# 메인 실행 함수
main() {
    log_info "KOSA EKS 모니터링 스택 배포를 시작합니다..."
    
    # 사전 확인
    check_kubectl
    
    # 단계별 배포
    setup_namespaces
    deploy_prometheus
    
    # Redis Exporter는 Redis가 배포된 경우에만 배포
    if deploy_redis_exporter; then
        log_success "Redis Exporter 배포 성공"
    else
        log_warning "Redis Exporter 배포 건너뜀 (Redis 먼저 배포 필요)"
    fi
    
    deploy_grafana
    
    # 상태 확인
    check_services
    
    # 포트 포워딩 안내
    setup_port_forwarding
    
    log_success "🎉 모니터링 스택 배포가 완료되었습니다!"
    echo ""
    echo "다음 단계:"
    echo "1. 포트 포워딩을 설정하여 대시보드에 접근"
    echo "2. Grafana에서 KOSA 시스템 대시보드 확인"
    echo "3. Prometheus에서 메트릭 수집 상태 확인"
}

# 스크립트 실행
main "$@"