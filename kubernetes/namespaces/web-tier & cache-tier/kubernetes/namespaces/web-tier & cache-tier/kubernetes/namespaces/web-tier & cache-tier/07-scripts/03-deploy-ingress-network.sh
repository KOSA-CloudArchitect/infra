#!/bin/bash

# EKS Migration - Ingress 및 Network Policy 배포 스크립트
# Task 5: Ingress 및 네트워크 설정 배포

set -e

echo "🚀 EKS Ingress 및 Network Policy 배포 시작..."

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

# 네임스페이스 존재 확인
check_namespace() {
    local namespace=$1
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "네임스페이스 '$namespace' 존재 확인"
        return 0
    else
        log_error "네임스페이스 '$namespace'가 존재하지 않습니다"
        return 1
    fi
}

# AWS Load Balancer Controller 설치 확인
check_alb_controller() {
    log_info "AWS Load Balancer Controller 설치 상태 확인..."
    
    if kubectl get deployment aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
        local ready_replicas=$(kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.status.readyReplicas}')
        local desired_replicas=$(kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.spec.replicas}')
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" -gt 0 ]; then
            log_success "AWS Load Balancer Controller가 정상 실행 중입니다 ($ready_replicas/$desired_replicas)"
            return 0
        else
            log_warning "AWS Load Balancer Controller가 완전히 준비되지 않았습니다 ($ready_replicas/$desired_replicas)"
            return 1
        fi
    else
        log_error "AWS Load Balancer Controller가 설치되지 않았습니다"
        log_info "다음 명령으로 설치하세요:"
        echo "  helm repo add eks https://aws.github.io/eks-charts"
        echo "  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \\"
        echo "    -n kube-system \\"
        echo "    --set clusterName=hihypipe-cluster \\"
        echo "    --set serviceAccount.create=false \\"
        echo "    --set serviceAccount.name=aws-load-balancer-controller"
        return 1
    fi
}

# 필수 네임스페이스 확인
log_info "필수 네임스페이스 존재 확인..."
required_namespaces=("web-tier" "cache-tier" "monitoring")
missing_namespaces=()

for ns in "${required_namespaces[@]}"; do
    if ! check_namespace "$ns"; then
        missing_namespaces+=("$ns")
    fi
done

if [ ${#missing_namespaces[@]} -gt 0 ]; then
    log_error "다음 네임스페이스가 누락되었습니다: ${missing_namespaces[*]}"
    log_info "먼저 01-namespaces.yaml을 배포하세요:"
    echo "  kubectl apply -f k8s-manifests/01-namespaces.yaml"
    exit 1
fi

# AWS Load Balancer Controller 확인
if ! check_alb_controller; then
    log_error "AWS Load Balancer Controller가 준비되지 않았습니다"
    exit 1
fi

# Ingress 리소스 배포
log_info "Ingress 리소스 배포 중..."
if kubectl apply -f k8s-manifests/07-ingress-resources.yaml; then
    log_success "Ingress 리소스 배포 완료"
else
    log_error "Ingress 리소스 배포 실패"
    exit 1
fi

# Network Policy 배포
log_info "Network Policy 배포 중..."
if kubectl apply -f k8s-manifests/08-network-policies.yaml; then
    log_success "Network Policy 배포 완료"
else
    log_error "Network Policy 배포 실패"
    exit 1
fi

# 배포 상태 확인
log_info "배포 상태 확인 중..."

echo ""
log_info "=== Ingress 리소스 상태 ==="
kubectl get ingress -n web-tier
kubectl get ingress -n monitoring

echo ""
log_info "=== Network Policy 상태 ==="
kubectl get networkpolicy -n web-tier
kubectl get networkpolicy -n cache-tier
kubectl get networkpolicy -n monitoring

echo ""
log_info "=== ALB 생성 상태 확인 ==="
log_warning "ALB 생성에는 2-3분이 소요될 수 있습니다..."

# ALB 생성 대기 (최대 5분)
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    alb_address=$(kubectl get ingress web-tier-ingress -n web-tier -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$alb_address" ]; then
        log_success "ALB 생성 완료: $alb_address"
        break
    fi
    
    echo -n "."
    sleep 10
    elapsed=$((elapsed + 10))
done

if [ $elapsed -ge $timeout ]; then
    log_warning "ALB 생성 확인 시간 초과. 수동으로 확인하세요:"
    echo "  kubectl get ingress -n web-tier"
fi

echo ""
log_success "🎉 Ingress 및 Network Policy 배포가 완료되었습니다!"

echo ""
log_info "=== 다음 단계 ==="
echo "1. ALB DNS 이름 확인:"
echo "   kubectl get ingress web-tier-ingress -n web-tier"
echo ""
echo "2. 서비스 연결 테스트:"
echo "   curl http://<ALB-DNS-NAME>/health"
echo ""
echo "3. SSL 인증서 설정 (프로덕션 환경):"
echo "   - ACM에서 SSL 인증서 생성"
echo "   - 07-ingress-resources.yaml에서 certificate-arn 주석 업데이트"
echo ""
echo "4. 도메인 설정:"
echo "   - Route 53에서 도메인을 ALB로 연결"
echo "   - Ingress 리소스에 host 규칙 추가"