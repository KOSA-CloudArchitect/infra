#!/bin/bash

# Kafka 클러스터 통합 배포 스크립트
# 모든 필요한 리소스를 올바른 순서로 배포
#
# 사용법:
#   ./deploy-kafka.sh                    # 기본 배포 (Namespace만 생성, Quota/Limit 미적용)

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}📋 $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 전역 변수
NAMESPACE="kafka"
CLUSTER_NAME="my-cluster"

# 함수: kubectl 연결 확인
check_kubectl_connection() {
    log_info "kubectl 연결 상태 확인 중..."
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log_error "kubectl이 클러스터에 연결되지 않았습니다."
        exit 1
    fi
    log_success "kubectl 연결 확인 완료"
}

# 함수: Helm 설치 확인
check_helm_installation() {
    log_info "Helm 설치 상태 확인 중..."
    if ! command -v helm &> /dev/null; then
        log_error "Helm이 설치되지 않았습니다."
        echo "  Kafka 배포에는 Strimzi Operator 설치가 필요하여 Helm이 요구됩니다."
        echo "  Helm 설치 후 다시 실행해주세요."
        echo "  Helm 설치 가이드: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    log_success "Helm 설치 확인 완료"
}

# 함수: AWS EBS CSI Driver 설치 확인
check_ebs_csi_driver() {
    log_info "AWS EBS CSI Driver 설치 확인 중..."
    if ! kubectl get csidriver ebs.csi.aws.com > /dev/null 2>&1; then
        log_error "AWS EBS CSI Driver가 설치되어 있지 않습니다. 먼저 설치 후 다시 실행해주세요."
        echo "  권장: EKS Managed Add-on 사용"
        echo "    aws eks create-addon \\
      --cluster-name <CLUSTER_NAME> \\
      --addon-name aws-ebs-csi-driver \\
      --addon-version latest"
        echo ""
        echo "  (선행) Pod Identity 연결 예시"
        echo "    aws eks create-pod-identity-association \\
      --cluster-name <CLUSTER_NAME> \\
      --namespace kube-system \\
      --service-account ebs-csi-controller-sa \\
      --role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole"
        echo ""
        echo "  대안: Helm 설치 경로(환경 제약 시)"
        echo "    helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
        echo "    helm repo update"
        echo "    helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver -n kube-system --create-namespace"
        exit 1
    fi
    log_success "AWS EBS CSI Driver 확인 완료"
}

# 함수: Kafka Connect용 Pod Identity/IRSA 연결 확인
check_connect_pod_identity_association() {
    log_info "Kafka Connect Pod Identity/IRSA 연결 확인 중..."
    local CONNECT_NAME="my-connect"
    local CONNECT_NAMESPACE="kafka"
    local CONNECT_SA="${CONNECT_NAME}-connect"

    # Kafka Connect가 생성한 ServiceAccount 존재 확인(일반적으로 <name>-connect)
    if ! kubectl get sa "$CONNECT_SA" -n "$CONNECT_NAMESPACE" > /dev/null 2>&1; then
        log_warning "ServiceAccount ${CONNECT_SA} 가 아직 존재하지 않습니다. (Kafka Connect 배포 이후 재확인 필요)"
        echo "  Kafka Connect 배포 후, 아래 명령으로 Pod Identity를 연결하세요:"
        echo "    aws eks create-pod-identity-association \\
      --cluster-name <CLUSTER_NAME> \\
      --namespace ${CONNECT_NAMESPACE} \\
      --service-account ${CONNECT_SA} \\
      --role-arn arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_FOR_CONNECT>"
        echo "  IRSA를 사용할 경우, ServiceAccount에 role-arn annotation을 부여하세요:"
        echo "    kubectl annotate sa ${CONNECT_SA} -n ${CONNECT_NAMESPACE} \\
      eks.amazonaws.com/role-arn=arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_FOR_CONNECT> --overwrite"
        return 0
    fi

    # IRSA 여부 확인(주요 케이스). Pod Identity 사용 시 주석 없이도 정상일 수 있음.
    local role_arn
    role_arn=$(kubectl get sa "$CONNECT_SA" -n "$CONNECT_NAMESPACE" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || true)
    if [ -n "$role_arn" ]; then
        log_success "Kafka Connect IRSA 연결 감지됨: $role_arn"
    else
        log_warning "Kafka Connect ServiceAccount에 IRSA annotation이 없습니다. Pod Identity 사용 여부를 확인하세요."
        echo "  Pod Identity 연결 상태 확인:"
        echo "    aws eks list-pod-identity-associations --cluster-name <CLUSTER_NAME>"
        echo "  연결이 없다면 다음 명령으로 연결하세요:"
        echo "    aws eks create-pod-identity-association \\
      --cluster-name <CLUSTER_NAME> \\
      --namespace ${CONNECT_NAMESPACE} \\
      --service-account ${CONNECT_SA} \\
      --role-arn arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_FOR_CONNECT>"
    fi

    log_success "Kafka Connect 인증 연결 확인 단계 완료"
}

# 함수: Strimzi Operator 배포
deploy_strimzi_operator() {
    log_info "Strimzi Operator 배포 중..."
    
    # Helm repository 추가
    helm repo add strimzi https://strimzi.io/charts/ 2>/dev/null || true
    helm repo update
    
    # Kafka 노드에 배포하기 위한 설정
    local node_selector="eks.amazonaws.com/nodegroup=kafka-storage-on-20250908020539785800000018"
    
    # 기존 설치 확인
    if helm list -n kafka | grep -q "strimzi-operator"; then
        log_warning "Strimzi Operator가 이미 설치되어 있습니다. 업그레이드를 진행합니다..."
        helm upgrade strimzi-operator strimzi/strimzi-kafka-operator \
            --version 0.47.0 \
            --namespace kafka \
            --set nodeSelector."eks\.amazonaws\.com/nodegroup"=kafka-storage-on-20250908020539785800000018 \
            --set tolerations[0].key=workload \
            --set tolerations[0].value=kafka \
            --set tolerations[0].effect=NoSchedule \
            --wait
    else
        log_info "Strimzi Operator를 새로 설치합니다..."
        helm install strimzi-operator strimzi/strimzi-kafka-operator \
            --version 0.47.0 \
            --namespace kafka \
            --create-namespace \
            --set nodeSelector."eks\.amazonaws\.com/nodegroup"=kafka-storage-on-20250908020539785800000018 \
            --set tolerations[0].key=workload \
            --set tolerations[0].value=kafka \
            --set tolerations[0].effect=NoSchedule \
            --wait
    fi
    
    log_success "Strimzi Operator 배포 완료"
}

# 함수: Kafka Connect 배포 (prebuilt)
deploy_kafka_connect() {
    log_info "Kafka Connect (prebuilt) 배포 중..."
    
    
    # Kafka Connect 배포
    kubectl apply -f kafka-connect-prebuilt.yaml
    
    log_success "Kafka Connect 배포 완료"
}

# 함수: Kafka Connector 배포
deploy_kafka_connectors() {
    log_info "Kafka Connector 배포 중..."
    
    # 기존 Connector들 정리
    log_info "기존 Kafka Connector 정리 중..."
    kubectl delete kafkaconnector --all -n $NAMESPACE --ignore-not-found=true
    
    # Connector 삭제 완료 대기
    log_info "기존 Connector 삭제 완료 대기 중..."
    timeout=60
    counter=0
    while [ $counter -lt $timeout ]; do
        existing_connectors=$(kubectl get kafkaconnector -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$existing_connectors" -eq 0 ]; then
            log_success "기존 Connector 정리 완료"
            break
        fi
        
        echo -n "."
        sleep 2
        counter=$((counter + 2))
    done
    
    if [ $counter -ge $timeout ]; then
        log_warning "기존 Connector 정리 대기 시간 초과. 강제로 진행합니다."
    fi
    
    # 새로운 Connector 배포
    log_info "새로운 Kafka Connector 배포 중..."
    
    # S3 Sink Connector만 배포
    connector_files=(
        "kafka-s3-sink-connector.yaml"
    )
    
    for connector_file in "${connector_files[@]}"; do
        if [ -f "$connector_file" ]; then
            log_info "배포 중: $connector_file"
            kubectl apply -f "$connector_file"
        else
            log_warning "파일을 찾을 수 없습니다: $connector_file"
        fi
    done
    
    # Connector 생성 확인
    log_info "Kafka Connector 생성 확인 중..."
    timeout=60
    counter=0
    while [ $counter -lt $timeout ]; do
        # 모든 Connector가 생성되었는지 확인
        total_connectors=$(kubectl get kafkaconnector -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$total_connectors" -gt 0 ]; then
            log_success "Kafka Connector 생성 확인 완료 (총 $total_connectors 개)"
            break
        fi
        
        echo -n "."
        sleep 3
        counter=$((counter + 3))
    done
    
    if [ $counter -ge $timeout ]; then
        log_warning "Kafka Connector 생성 대기 시간 초과. 수동으로 확인해주세요."
        log_info "Connector 상태 확인: kubectl get kafkaconnector -n $NAMESPACE"
    else
        log_success "Kafka Connector 배포 완료"
    fi
}

# 함수: 기존 리소스 정리
cleanup_existing_resources() {
    log_info "기존 Kafka 리소스 정리 중..."
    
    # Kafka 클러스터 삭제
    kubectl delete kafka $CLUSTER_NAME -n $NAMESPACE --ignore-not-found=true
    
    # NodePools 삭제
    kubectl delete kafkanodepool --all -n $NAMESPACE --ignore-not-found=true
    
    # PVC 삭제
    kubectl delete pvc --all -n $NAMESPACE --ignore-not-found=true
    
    log_success "기존 리소스 정리 완료"
}

# 함수: 네임스페이스 생성 (Quota/Limit 미적용, 기본값 사용)
deploy_namespace() {
    log_info "네임스페이스 생성 중... (ResourceQuota/LimitRange 미적용)"
    
    # 네임스페이스만 생성
    kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace kafka name=kafka purpose=kafka-cluster --overwrite
    
    # 과거 배포에서 남아있을 수 있는 Quota/LimitRange 제거로 기본 동작 보장
    kubectl delete resourcequota --all -n kafka --ignore-not-found=true
    kubectl delete limitrange --all -n kafka --ignore-not-found=true
    
    log_success "네임스페이스 준비 완료 (Quota/Limit 없음)"
}

# 함수: StorageClass 배포
deploy_storageclass() {
    log_info "StorageClass 배포 중..."
    kubectl apply -f storageclass.yaml
    
    # 기존 기본 StorageClass 비활성화 (존재하는 경우에만)
    if kubectl get storageclass gp2 > /dev/null 2>&1; then
        kubectl patch storageclass gp2 -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
        log_info "gp2 StorageClass를 기본에서 제거했습니다."
    else
        log_info "gp2 StorageClass가 존재하지 않습니다. 건너뜁니다."
    fi
    
    log_success "StorageClass 배포 완료"
}

# 함수: Kafka 클러스터 배포
deploy_kafka_cluster() {
    log_info "Kafka 클러스터 배포 중..."
    kubectl apply -f kafka_crd.yaml
    log_success "Kafka 클러스터 배포 완료"
}

# 함수: Kafka Topic 배포
deploy_kafka_topics() {
    log_info "Kafka Topic 배포 중..."
    kubectl apply -f kafka-topic.yaml
    log_success "Kafka Topic 배포 완료"
}

# 함수: Kafka Bridge 배포
deploy_kafka_bridge() {
    log_info "Kafka Bridge 배포 중..."
    kubectl apply -f kafka_bridge.yaml
    log_success "Kafka Bridge 배포 완료"
}

# 함수: 배포 상태 확인
check_deployment_status() {
    log_info "배포 상태 확인 중..."
    
    echo ""
    log_info "=== Strimzi Operator 상태 ==="
    kubectl get pods -n $NAMESPACE | grep strimzi || echo "Strimzi Operator Pod 없음"
    
    echo ""
    log_info "=== Kafka 클러스터 상태 ==="
    kubectl get kafka -n $NAMESPACE
    
    echo ""
    log_info "=== Kafka NodePools 상태 ==="
    kubectl get kafkanodepool -n $NAMESPACE
    
    echo ""
    log_info "=== Kafka Connect 상태 ==="
    kubectl get kafkaconnect -n $NAMESPACE
    
    echo ""
    log_info "=== Kafka Connector 상태 ==="
    kubectl get kafkaconnector -n $NAMESPACE
    
    # Connector 상세 정보 표시
    echo ""
    log_info "=== Kafka Connector 상세 정보 ==="
    kubectl get kafkaconnector -n $NAMESPACE --no-headers 2>/dev/null | while read name ready replicas; do
        if [ -n "$name" ]; then
            echo "Connector: $name"
            kubectl describe kafkaconnector "$name" -n $NAMESPACE | grep -E "(State|Status|Tasks|Error)" || echo "  상세 정보 없음"
            echo "---"
        fi
    done
    
    echo ""
    log_info "=== Pod 상태 ==="
    kubectl get pods -n $NAMESPACE
    
    echo ""
    log_info "=== PVC 상태 ==="
    kubectl get pvc -n $NAMESPACE
    
    echo ""
    log_info "=== StorageClass 상태 ==="
    kubectl get storageclass
}

# 함수: 배포 완료 대기
wait_for_deployment() {
    log_info "Kafka Pod 실행 완료 대기 중..."
    
    # Pod가 Running 상태가 될 때까지 대기 (최대 5분)
    timeout=300
    counter=0
    
    while [ $counter -lt $timeout ]; do
        running_pods=$(kubectl get pods -n $NAMESPACE --no-headers | grep -c "Running" || true)
        total_pods=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l || true)
        
        if [ "$running_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            log_success "모든 Kafka Pod가 실행 중입니다!"
            break
        fi
        
        echo -n "."
        sleep 5
        counter=$((counter + 5))
    done
    
    if [ $counter -ge $timeout ]; then
        log_warning "Pod 실행 대기 시간 초과. 수동으로 상태를 확인해주세요."
    fi
}

# 함수: Kafka 클러스터 완전 준비 대기
wait_for_kafka_cluster_ready() {
    log_info "Kafka 클러스터 완전 준비 대기 중..."
    
    timeout=600  # 10분
    counter=0
    
    while [ $counter -lt $timeout ]; do
        # Kafka 클러스터 상태 확인
        kafka_status=$(kubectl get kafka $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        
        if [ "$kafka_status" = "True" ]; then
            log_success "Kafka 클러스터가 완전히 준비되었습니다!"
            return 0
        fi
        
        echo -n "."
        sleep 10
        counter=$((counter + 10))
    done
    
    log_warning "Kafka 클러스터 준비 대기 시간 초과. 수동으로 상태를 확인해주세요."
    return 1
}

# 메인 실행 함수
main() {
    log_info "🚀 Kafka 클러스터 통합 배포 시작..."
    
    # 1. kubectl 연결 확인
    check_kubectl_connection
    
    # 2. Helm 설치 확인
    check_helm_installation
    
    # 3. EBS CSI Driver 확인 (필수)
    check_ebs_csi_driver
    
    # 4. (Kafka Connect를 위한) Pod Identity/IRSA 연결은 Connect 배포 이후에 확인
    
    # 5. 기존 리소스 정리
    cleanup_existing_resources
    
    # 6. 네임스페이스 배포
    deploy_namespace
    
    # 7. Strimzi Operator 배포
    deploy_strimzi_operator
    
    # 8. StorageClass 배포
    deploy_storageclass
    
    # 9. Kafka 클러스터 배포
    deploy_kafka_cluster
    
    # 10. 배포 완료 대기
    wait_for_deployment
    
    # 11. Kafka 클러스터 완전 준비 대기
    if wait_for_kafka_cluster_ready; then
        log_success "Kafka 클러스터가 준비되었습니다. Connect 및 Connector 배포를 진행합니다."
        
        # 12. Kafka Topic 배포
        deploy_kafka_topics
        
        # 13. Kafka Bridge 배포
        deploy_kafka_bridge
        
        # 14. Kafka Connect 배포 (prebuilt)
        deploy_kafka_connect
        
        # 15. Kafka Connect용 Pod Identity/IRSA 연결 확인 (권장)
        check_connect_pod_identity_association

        # 16. Kafka Connector 배포 (마지막)
        deploy_kafka_connectors
        
        log_success "🎉 Kafka 클러스터 및 Connect 통합 배포 완료!"
    else
        log_warning "Kafka 클러스터 준비에 실패했습니다. Connect 및 Connector 배포를 건너뜁니다."
        log_info "수동으로 Kafka 클러스터 상태를 확인한 후 Connect를 배포해주세요."
    fi
    
    # 17. 최종 상태 확인
    check_deployment_status
    
    echo ""
    log_info "📝 유용한 명령어들:"
    echo "  - Pod 상태 확인: kubectl get pods -n $NAMESPACE"
    echo "  - Kafka 클러스터 상태: kubectl get kafka -n $NAMESPACE"
    echo "  - Kafka Connect 상태: kubectl get kafkaconnect -n $NAMESPACE"
    echo "  - Kafka Connector 상태: kubectl get kafkaconnector -n $NAMESPACE"
    echo "  - Connector 상세 정보: kubectl describe kafkaconnector <connector-name> -n $NAMESPACE"
    echo "  - Connector 재시작: kubectl delete kafkaconnector <connector-name> -n $NAMESPACE && kubectl apply -f <connector-file>"
    echo "  - 모든 Connector 삭제: kubectl delete kafkaconnector --all -n $NAMESPACE"
    echo "  - PVC 상태 확인: kubectl get pvc -n $NAMESPACE"
    echo "  - 로그 확인: kubectl logs -n $NAMESPACE <pod-name>"
    echo "  - Kafka Bridge 접근: kubectl port-forward -n $NAMESPACE service/my-cluster-kafka-bridge 8080:8080"
    echo "  - Kafka Connect REST API: kubectl port-forward -n $NAMESPACE service/my-connect-connect-api 8083:8083"
}

# 스크립트 실행
main "$@"
