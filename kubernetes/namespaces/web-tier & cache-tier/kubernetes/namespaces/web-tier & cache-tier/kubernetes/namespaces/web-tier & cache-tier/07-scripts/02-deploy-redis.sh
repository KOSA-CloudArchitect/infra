#!/bin/bash

# Redis EKS 배포 스크립트
# Task 4.2: Redis Service 및 헬스체크 설정 - 배포 자동화

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
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

# 전역 변수
NAMESPACE="cache-tier"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 사전 요구사항 확인
check_prerequisites() {
    log_info "사전 요구사항 확인 중..."
    
    # kubectl 설치 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # 클러스터 연결 확인
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Kubernetes 클러스터에 연결할 수 없습니다."
        exit 1
    fi
    
    # 네임스페이스 존재 확인
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "네임스페이스 '$NAMESPACE'가 존재하지 않습니다."
        log_info "다음 명령어로 네임스페이스를 생성하세요:"
        log_info "kubectl apply -f k8s-manifests/01-namespaces.yaml"
        exit 1
    fi
    
    log_success "사전 요구사항 확인 완료"
}

# Redis 배포 함수
deploy_redis() {
    log_info "Redis 클러스터 배포 시작..."
    
    # 1. ConfigMap 및 Secret 배포
    log_info "1/5: ConfigMap 및 Secret 배포 중..."
    kubectl apply -f "$SCRIPT_DIR/redis-configmap.yaml"
    kubectl apply -f "$SCRIPT_DIR/redis-secret.yaml"
    log_success "ConfigMap 및 Secret 배포 완료"
    
    # 2. Redis Master 배포
    log_info "2/5: Redis Master 배포 중..."
    kubectl apply -f "$SCRIPT_DIR/redis-master-statefulset.yaml"
    
    # Master Pod 준비 대기
    log_info "Redis Master Pod 준비 대기 중..."
    kubectl wait --for=condition=ready pod/redis-master-0 -n $NAMESPACE --timeout=300s
    log_success "Redis Master 배포 완료"
    
    # 3. Redis Slave 배포
    log_info "3/5: Redis Slave 배포 중..."
    kubectl apply -f "$SCRIPT_DIR/redis-slave-statefulset.yaml"
    
    # Slave Pod 준비 대기
    log_info "Redis Slave Pod 준비 대기 중..."
    kubectl wait --for=condition=ready pod/redis-slave-0 -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod/redis-slave-1 -n $NAMESPACE --timeout=300s
    log_success "Redis Slave 배포 완료"
    
    # 4. Services 배포
    log_info "4/5: Redis Services 배포 중..."
    kubectl apply -f "$SCRIPT_DIR/redis-services.yaml"
    log_success "Redis Services 배포 완료"
    
    # 5. 모니터링 설정
    log_info "5/5: Redis 모니터링 설정 중..."
    kubectl apply -f "$SCRIPT_DIR/redis-monitoring.yaml"
    log_success "Redis 모니터링 설정 완료"
    
    log_success "Redis 클러스터 배포 완료!"
}

# Redis 상태 확인
check_redis_status() {
    log_info "Redis 클러스터 상태 확인 중..."
    
    # Pod 상태 확인
    echo ""
    log_info "=== Pod 상태 ==="
    kubectl get pods -n $NAMESPACE -l app=redis -o wide
    
    # Service 상태 확인
    echo ""
    log_info "=== Service 상태 ==="
    kubectl get services -n $NAMESPACE -l app=redis
    
    # PVC 상태 확인
    echo ""
    log_info "=== PVC 상태 ==="
    kubectl get pvc -n $NAMESPACE
    
    # Redis 연결 테스트
    echo ""
    log_info "=== Redis 연결 테스트 ==="
    
    # Master 연결 테스트
    log_info "Master 연결 테스트..."
    if kubectl exec -it -n $NAMESPACE redis-master-0 -- redis-cli -a redis-secure-password-2024 ping &> /dev/null; then
        log_success "✅ Master 연결 성공"
    else
        log_error "❌ Master 연결 실패"
    fi
    
    # Slave 연결 테스트
    for i in 0 1; do
        log_info "Slave-$i 연결 테스트..."
        if kubectl exec -it -n $NAMESPACE redis-slave-$i -- redis-cli -a redis-secure-password-2024 ping &> /dev/null; then
            log_success "✅ Slave-$i 연결 성공"
        else
            log_error "❌ Slave-$i 연결 실패"
        fi
    done
    
    # 복제 상태 확인
    echo ""
    log_info "=== 복제 상태 확인 ==="
    kubectl exec -it -n $NAMESPACE redis-master-0 -- redis-cli -a redis-secure-password-2024 info replication | grep -E "(role|connected_slaves)"
}

# Redis 성능 테스트
performance_test() {
    log_info "Redis 성능 테스트 실행 중..."
    
    # 간단한 성능 테스트
    log_info "기본 성능 테스트 (1000 SET/GET 작업)..."
    kubectl exec -it -n $NAMESPACE redis-master-0 -- redis-cli -a redis-secure-password-2024 --latency-history -i 1 &
    LATENCY_PID=$!
    
    # 성능 테스트 실행
    kubectl exec -it -n $NAMESPACE redis-master-0 -- redis-cli -a redis-secure-password-2024 eval "
        for i=1,1000 do
            redis.call('SET', 'test:key:' .. i, 'test:value:' .. i)
            redis.call('GET', 'test:key:' .. i)
        end
        return 'Performance test completed'
    " 0
    
    # 지연시간 모니터링 중지
    kill $LATENCY_PID 2>/dev/null || true
    
    # 메모리 사용량 확인
    log_info "메모리 사용량 확인..."
    kubectl exec -it -n $NAMESPACE redis-master-0 -- redis-cli -a redis-secure-password-2024 info memory | grep used_memory_human
    
    # 테스트 데이터 정리
    kubectl exec -it -n $NAMESPACE redis-master-0 -- redis-cli -a redis-secure-password-2024 eval "
        local keys = redis.call('KEYS', 'test:key:*')
        if #keys > 0 then
            return redis.call('DEL', unpack(keys))
        end
        return 0
    " 0
    
    log_success "성능 테스트 완료"
}

# 백엔드 연결 테스트 (선택사항)
test_backend_connection() {
    log_info "백엔드 연결 테스트..."
    
    # 백엔드 Pod 찾기
    BACKEND_POD=$(kubectl get pods -n web-tier -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$BACKEND_POD" ]; then
        log_warning "백엔드 Pod를 찾을 수 없습니다. 백엔드가 배포되지 않았을 수 있습니다."
        return
    fi
    
    log_info "백엔드 Pod에서 Redis 연결 테스트: $BACKEND_POD"
    
    # Node.js 환경에서 Redis 연결 테스트
    kubectl exec -it -n web-tier $BACKEND_POD -- node -e "
        const Redis = require('ioredis');
        const client = new Redis({
            host: 'redis-service.cache-tier.svc.cluster.local',
            port: 6379,
            password: 'redis-secure-password-2024',
            connectTimeout: 5000,
            commandTimeout: 3000
        });
        
        client.ping()
            .then(result => {
                console.log('✅ 백엔드에서 Redis 연결 성공:', result);
                process.exit(0);
            })
            .catch(error => {
                console.error('❌ 백엔드에서 Redis 연결 실패:', error.message);
                process.exit(1);
            });
    " 2>/dev/null && log_success "백엔드 연결 테스트 성공" || log_error "백엔드 연결 테스트 실패"
}

# 정리 함수
cleanup_redis() {
    log_warning "Redis 클러스터 정리 중..."
    
    read -p "정말로 Redis 클러스터를 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "정리 작업이 취소되었습니다."
        return
    fi
    
    # 역순으로 삭제
    kubectl delete -f "$SCRIPT_DIR/redis-monitoring.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/redis-services.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/redis-slave-statefulset.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/redis-master-statefulset.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/redis-configmap.yaml" --ignore-not-found=true
    kubectl delete -f "$SCRIPT_DIR/redis-secret.yaml" --ignore-not-found=true
    
    # PVC 삭제 (데이터 손실 주의!)
    read -p "PVC도 삭제하시겠습니까? (데이터가 영구적으로 삭제됩니다) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete pvc -n $NAMESPACE -l app=redis
        log_warning "PVC가 삭제되었습니다. 데이터가 영구적으로 손실되었습니다."
    fi
    
    log_success "Redis 클러스터 정리 완료"
}

# 도움말 출력
show_help() {
    echo "Redis EKS 배포 스크립트"
    echo ""
    echo "사용법: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     Redis 클러스터 배포"
    echo "  status     Redis 클러스터 상태 확인"
    echo "  test       Redis 성능 테스트 실행"
    echo "  backend    백엔드 연결 테스트"
    echo "  cleanup    Redis 클러스터 정리"
    echo "  help       이 도움말 출력"
    echo ""
    echo "예시:"
    echo "  $0 deploy    # Redis 클러스터 배포"
    echo "  $0 status    # 상태 확인"
    echo "  $0 test      # 성능 테스트"
}

# 메인 함수
main() {
    case "${1:-help}" in
        "deploy")
            check_prerequisites
            deploy_redis
            check_redis_status
            ;;
        "status")
            check_redis_status
            ;;
        "test")
            performance_test
            ;;
        "backend")
            test_backend_connection
            ;;
        "cleanup")
            cleanup_redis
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 스크립트 실행
main "$@"