#!/bin/bash
# EKS Migration - Logging and Alerting Deployment Script
# Task 6.2: 로그 수집 및 알림 설정 배포

set -e

echo "🔧 KOSA EKS 로깅 및 알림 시스템 배포 시작..."

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

# monitoring 네임스페이스 확인
check_monitoring_namespace() {
    log_info "monitoring 네임스페이스 확인 중..."
    if ! kubectl get namespace monitoring &> /dev/null; then
        log_error "monitoring 네임스페이스가 존재하지 않습니다."
        log_info "먼저 모니터링 스택을 배포하세요: ./deploy-monitoring.sh"
        exit 1
    fi
    log_success "monitoring 네임스페이스 확인 완료"
}

# Fluent Bit 배포
deploy_fluent_bit() {
    log_info "Fluent Bit 로그 수집기 배포 중..."
    kubectl apply -f 12-logging-fluent-bit.yaml
    
    # Fluent Bit DaemonSet이 Ready 상태가 될 때까지 대기
    log_info "Fluent Bit DaemonSet 시작 대기 중..."
    kubectl rollout status daemonset/fluent-bit -n monitoring --timeout=300s
    log_success "Fluent Bit 배포 완료"
}

# AlertManager 배포
deploy_alertmanager() {
    log_info "AlertManager 배포 중..."
    kubectl apply -f 13-monitoring-alertmanager.yaml
    
    # AlertManager Pod가 Ready 상태가 될 때까지 대기
    log_info "AlertManager Pod 시작 대기 중..."
    kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=300s
    log_success "AlertManager 배포 완료"
}

# Prometheus 설정 업데이트 (AlertManager 연동)
update_prometheus_config() {
    log_info "Prometheus 설정 업데이트 중 (AlertManager 연동)..."
    kubectl apply -f 09-monitoring-prometheus.yaml
    
    # Prometheus Pod 재시작 대기
    log_info "Prometheus 설정 적용 대기 중..."
    kubectl rollout restart deployment/prometheus -n monitoring
    kubectl rollout status deployment/prometheus -n monitoring --timeout=300s
    log_success "Prometheus 설정 업데이트 완료"
}

# CloudWatch Logs 그룹 생성 (AWS CLI 필요)
setup_cloudwatch_logs() {
    log_info "CloudWatch Logs 그룹 설정 확인 중..."
    
    if command -v aws &> /dev/null; then
        # CloudWatch Logs 그룹 생성 (이미 존재하면 무시)
        aws logs create-log-group --log-group-name "/aws/eks/hihypipe-cluster/application" --region ap-northeast-2 2>/dev/null || true
        log_success "CloudWatch Logs 그룹 설정 완료"
    else
        log_warning "AWS CLI가 설치되지 않았습니다. CloudWatch Logs 그룹을 수동으로 생성하세요."
        echo "Log Group Name: /aws/eks/hihypipe-cluster/application"
        echo "Region: ap-northeast-2"
    fi
}

# 서비스 상태 확인
check_services() {
    log_info "배포된 로깅 및 알림 서비스 상태 확인 중..."
    
    echo ""
    echo "=== Fluent Bit DaemonSet ==="
    kubectl get daemonset fluent-bit -n monitoring -o wide
    kubectl get pods -n monitoring -l app=fluent-bit -o wide
    
    echo ""
    echo "=== AlertManager ==="
    kubectl get deployment alertmanager -n monitoring -o wide
    kubectl get pods -n monitoring -l app=alertmanager -o wide
    kubectl get services -n monitoring -l app=alertmanager
    
    echo ""
    echo "=== Prometheus (업데이트됨) ==="
    kubectl get pods -n monitoring -l app=prometheus -o wide
}

# 로그 및 알림 테스트
test_logging_alerts() {
    log_info "로깅 및 알림 시스템 테스트 중..."
    
    # Fluent Bit 로그 확인
    echo ""
    echo "=== Fluent Bit 로그 샘플 ==="
    kubectl logs -n monitoring -l app=fluent-bit --tail=10 | head -20
    
    # AlertManager 상태 확인
    echo ""
    echo "=== AlertManager 상태 ==="
    kubectl exec -n monitoring deployment/alertmanager -- wget -qO- http://localhost:9093/-/healthy || log_warning "AlertManager 헬스체크 실패"
    
    log_success "로깅 및 알림 시스템 테스트 완료"
}

# 포트 포워딩 설정 안내
setup_port_forwarding() {
    log_info "포트 포워딩 설정 안내:"
    echo ""
    echo "다음 명령어들을 사용하여 로깅 및 알림 대시보드에 접근할 수 있습니다:"
    echo ""
    echo "# AlertManager (포트 9093)"
    echo "kubectl port-forward -n monitoring svc/alertmanager-service 9093:9093"
    echo ""
    echo "# Fluent Bit 메트릭 (포트 2021)"
    echo "kubectl port-forward -n monitoring svc/fluent-bit-service 2021:2021"
    echo ""
    echo "접근 URL:"
    echo "  - AlertManager: http://localhost:9093"
    echo "  - Fluent Bit 메트릭: http://localhost:2021/metrics"
    echo ""
}

# 메인 실행 함수
main() {
    log_info "KOSA EKS 로깅 및 알림 시스템 배포를 시작합니다..."
    
    # 사전 확인
    check_kubectl
    check_monitoring_namespace
    
    # CloudWatch Logs 설정
    setup_cloudwatch_logs
    
    # 단계별 배포
    deploy_fluent_bit
    deploy_alertmanager
    update_prometheus_config
    
    # 상태 확인
    check_services
    
    # 테스트
    test_logging_alerts
    
    # 포트 포워딩 안내
    setup_port_forwarding
    
    log_success "🎉 로깅 및 알림 시스템 배포가 완료되었습니다!"
    echo ""
    echo "다음 단계:"
    echo "1. CloudWatch Logs에서 애플리케이션 로그 확인"
    echo "2. AlertManager에서 알림 규칙 테스트"
    echo "3. Grafana에서 로그 메트릭 대시보드 확인"
    echo "4. 백엔드 애플리케이션에서 /api/alerts/test 엔드포인트로 알림 테스트"
}

# 스크립트 실행
main "$@"