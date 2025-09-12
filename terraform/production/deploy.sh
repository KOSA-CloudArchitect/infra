#!/bin/bash

# =============================================================================
# Production Environment Deployment Script
# =============================================================================

set -e  # 오류 발생 시 스크립트 중단

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

# kubectl 연결 설정 함수 (macOS 호환 버전)
setup_kubectl_connection() {
    log_info "kubectl 연결 설정 중..."
    
    # 클러스터 이름과 리전 설정
    CLUSTER_NAME="hihypipe-eks-cluster"
    AWS_REGION="ap-northeast-2"
    
    log_info "클러스터: $CLUSTER_NAME, 리전: $AWS_REGION"
    
    # kubectl 설정 업데이트 (macOS 호환)
    log_info "kubectl 설정 업데이트 중..."
    
    # 기존 kubeconfig 백업
    if [ -f ~/.kube/config ]; then
        cp ~/.kube/config ~/.kube/config.backup.$(date +%s)
    fi
    
    # kubectl 설정 업데이트 (백그라운드 실행으로 자동화)
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --alias $CLUSTER_NAME &
    UPDATE_PID=$!
    
    # 최대 30초 대기
    for i in {1..30}; do
        if ! kill -0 $UPDATE_PID 2>/dev/null; then
            break
        fi
        sleep 1
    done
    
    # 프로세스가 아직 실행 중이면 강제 종료
    if kill -0 $UPDATE_PID 2>/dev/null; then
        kill $UPDATE_PID 2>/dev/null
        log_warning "kubectl 설정 업데이트가 30초 내에 완료되지 않았습니다."
    fi
    
    # 설정 완료 확인
    if kubectl config get-contexts | grep -q $CLUSTER_NAME; then
        log_success "kubectl 연결 설정 완료"
        
        # 연결 테스트
        log_info "연결 테스트 중..."
        kubectl get nodes --request-timeout=10s &>/dev/null
        if [ $? -eq 0 ]; then
            log_success "클러스터 연결 성공"
        else
            log_warning "클러스터 연결 테스트 실패 (노드가 아직 준비되지 않았을 수 있음)"
        fi
    else
        log_error "kubectl 연결 설정 실패"
        return 1
    fi
}

# 배포 단계별 함수
deploy_phase1() {
    log_info "Phase 1: 기본 인프라 배포 시작..."
    
    log_info "VPC APP 배포 중..."
    terraform apply -target=module.vpc_app -auto-approve
    
    log_info "VPC DB 배포 중..."
    terraform apply -target=module.vpc_db -auto-approve
    
    log_info "VPC 피어링 연결 중..."
    terraform apply -target=aws_vpc_peering_connection.app_to_db -auto-approve
    
    log_info "VPC 라우팅 테이블 업데이트 중..."
    terraform apply -target=aws_route.app_to_db -auto-approve
    terraform apply -target=aws_route.db_to_app -auto-approve
    
    log_success "Phase 1 완료: 기본 인프라 배포됨"
}

deploy_phase2() {
    log_info "Phase 2: 보안 및 IAM 배포 시작..."
    
    log_info "IAM 역할 생성 중..."
    terraform apply -target=aws_iam_role.jenkins_role -auto-approve
    terraform apply -target=aws_iam_role.ebs_csi_driver -auto-approve
    terraform apply -target=aws_iam_role.cni_role -auto-approve
    # terraform apply -target=aws_iam_role.cluster_autoscaler -auto-approve  # 주석처리됨
    terraform apply -target=aws_iam_role.airflow_irsa -auto-approve
    terraform apply -target=aws_iam_role.spark_irsa -auto-approve
    
    log_info "IAM 정책 생성 중..."
    terraform apply -target=aws_iam_policy.jenkins_policy -auto-approve
    # terraform apply -target=aws_iam_policy.cluster_autoscaler_policy -auto-approve  # 주석처리됨
    terraform apply -target=aws_iam_policy.airflow_s3_policy -auto-approve
    terraform apply -target=aws_iam_policy.spark_s3_policy -auto-approve
    
    log_info "IAM 정책 첨부 중..."
    terraform apply -target=aws_iam_role_policy_attachment.jenkins_policy_attachment -auto-approve
    terraform apply -target=aws_iam_role_policy_attachment.ebs_csi_driver_policy -auto-approve
    terraform apply -target=aws_iam_role_policy_attachment.cni_policy_attachment -auto-approve
    # terraform apply -target=aws_iam_role_policy_attachment.cluster_autoscaler_policy_attachment -auto-approve  # 주석처리됨
    terraform apply -target=aws_iam_role_policy_attachment.airflow_s3_policy_attachment -auto-approve
    terraform apply -target=aws_iam_role_policy_attachment.spark_s3_policy_attachment -auto-approve
    
    log_info "IAM 인스턴스 프로파일 생성 중..."
    terraform apply -target=aws_iam_instance_profile.jenkins_instance_profile -auto-approve
    
    log_success "Phase 2 완료: 보안 및 IAM 배포됨"
}

deploy_phase3() {
    log_info "Phase 3: 데이터베이스 배포 시작..."
    
    log_info "RDS 서브넷 그룹 생성 중..."
    terraform apply -target=aws_db_subnet_group.rds_subnet_group -auto-approve
    
    log_info "RDS 보안 그룹 생성 중..."
    terraform apply -target=aws_security_group.rds_sg -auto-approve
    
    log_info "RDS 데이터베이스 생성 중..."
    terraform apply -target=aws_db_instance.airflow_db -auto-approve
    
    log_success "Phase 3 완료: 데이터베이스 배포됨"
}

deploy_phase4() {
    log_info "Phase 4: 스토리지 배포 시작..."
    
    log_info "S3 버킷 생성 중..."
    terraform apply -target=aws_s3_bucket.airflow_logs -auto-approve
    terraform apply -target=aws_s3_bucket.spark_checkpoints -auto-approve
    
    log_info "S3 버킷 설정 중..."
    terraform apply -target=aws_s3_bucket_versioning.airflow_logs_versioning -auto-approve
    terraform apply -target=aws_s3_bucket_versioning.spark_checkpoints_versioning -auto-approve
    
    terraform apply -target=aws_s3_bucket_server_side_encryption_configuration.airflow_logs_encryption -auto-approve
    terraform apply -target=aws_s3_bucket_server_side_encryption_configuration.spark_checkpoints_encryption -auto-approve
    
    terraform apply -target=aws_s3_bucket_lifecycle_configuration.airflow_logs_lifecycle -auto-approve
    terraform apply -target=aws_s3_bucket_lifecycle_configuration.spark_checkpoints_lifecycle -auto-approve
    
    terraform apply -target=aws_s3_bucket_public_access_block.airflow_logs_pab -auto-approve
    terraform apply -target=aws_s3_bucket_public_access_block.spark_checkpoints_pab -auto-approve
    
    log_success "Phase 4 완료: 스토리지 배포됨"
}

deploy_phase5() {
    log_info "Phase 5: EKS 클러스터 배포 시작..."
    
    log_info "EKS 클러스터 생성 중..."
    terraform apply -target=module.eks -auto-approve
    
    log_info "EKS 퍼블릭 액세스 제한 중..."
    terraform apply -target=null_resource.restrict_eks_public_access -auto-approve
    
    log_success "Phase 5 완료: EKS 클러스터 배포됨"
}

deploy_phase6() {
    log_info "Phase 6: 노드 그룹 배포 시작..."
    
    log_info "핵심 노드 그룹 생성 중..."
    terraform apply -target=module.eks.eks_managed_node_groups.core_on -auto-approve
    terraform apply -target=module.eks.eks_managed_node_groups.airflow_core_on -auto-approve
    terraform apply -target=module.eks.eks_managed_node_groups.spark_driver_on -auto-approve
    terraform apply -target=module.eks.eks_managed_node_groups.kafka_storage_on -auto-approve
    
    log_info "Spot 노드 그룹 생성 중..."
    terraform apply -target=module.eks.eks_managed_node_groups.airflow_worker_spot -auto-approve
    terraform apply -target=module.eks.eks_managed_node_groups.spark_exec_spot -auto-approve
    terraform apply -target=module.eks.eks_managed_node_groups.gpu_spot -auto-approve
    
    log_success "Phase 6 완료: 노드 그룹 배포됨"
}

deploy_phase7() {
    log_info "Phase 7: VPN 연결 배포 시작..."
    
    log_info "VPN Gateway 생성 중..."
    terraform apply -target=aws_vpn_gateway.aws_vgw -auto-approve
    
    log_info "Customer Gateway 생성 중..."
    terraform apply -target=aws_customer_gateway.onprem_cgw -auto-approve
    
    log_info "VPN Connection 생성 중..."
    terraform apply -target=aws_vpn_connection.aws_to_onprem -auto-approve
    
    log_info "VPN Route 설정 중..."
    terraform apply -target=aws_vpn_connection_route.aws_to_onprem_route -auto-approve
    
    log_success "Phase 7 완료: VPN 연결 배포됨"
}

deploy_phase8() {
    log_info "Phase 8: Jenkins 서버 배포 시작..."
    
    log_info "Jenkins 보안 그룹 생성 중..."
    terraform apply -target=aws_security_group.alb_sg -auto-approve
    terraform apply -target=aws_security_group.jenkins_sg -auto-approve
    
    log_info "Jenkins ALB 생성 중..."
    terraform apply -target=aws_lb.jenkins_alb -auto-approve
    
    log_info "Jenkins 타겟 그룹 생성 중..."
    terraform apply -target=aws_lb_target_group.jenkins_tg -auto-approve
    
    log_info "Jenkins 리스너 생성 중..."
    terraform apply -target=aws_lb_listener.jenkins_listener -auto-approve
    
    log_info "Jenkins 서버 생성 중..."
    terraform apply -target=aws_instance.jenkins_controller -auto-approve
    
    log_info "Jenkins 타겟 그룹 첨부 중..."
    terraform apply -target=aws_lb_target_group_attachment.jenkins_attachment -auto-approve
    
    log_success "Phase 8 완료: Jenkins 서버 배포됨"
}

deploy_phase9() {
    log_info "Phase 9: Kubernetes 리소스 배포 시작..."
    
    # terraform.tfvars에서 create_k8s_resources를 true로 변경
    log_info "terraform.tfvars에서 create_k8s_resources를 true로 변경 중..."
    sed -i.bak 's/create_k8s_resources = false/create_k8s_resources = true/' terraform.tfvars
    
    # kubectl 연결 설정
    log_info "kubectl 연결 설정 중..."
    setup_kubectl_connection
    
    # EBS CSI Driver 설치 (kubectl 연결 후)
    log_info "EBS CSI Driver 설치 중..."
    terraform apply -target=helm_release.ebs_csi_driver -auto-approve
    
    log_info "Kubernetes 네임스페이스 및 서비스 어카운트 생성 중..."
    terraform apply -target=kubernetes_namespace.airflow -auto-approve
    terraform apply -target=kubernetes_namespace.spark -auto-approve
    terraform apply -target=kubernetes_service_account.airflow_irsa -auto-approve
    terraform apply -target=kubernetes_service_account.spark_irsa -auto-approve
    
    log_success "Phase 9 완료: Kubernetes 리소스 배포됨"
}

deploy_phase10() {
    log_info "Phase 10: 최종 검증 시작..."
    
    # kubectl 연결 확인
    log_info "kubectl 연결 상태 확인 중..."
    setup_kubectl_connection
    
    log_info "전체 인프라 검증 중..."
    terraform apply -auto-approve
    
    log_info "클러스터 상태 확인 중..."
    kubectl get nodes
    kubectl get pods -A
    kubectl get namespaces
    
    log_success "Phase 10 완료: 최종 검증 완료"
}

# 메인 함수
main() {
    log_info "Production 환경 배포를 시작합니다..."
    
    # 사전 체크
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform이 설치되지 않았습니다."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "Helm이 설치되지 않았습니다."
        exit 1
    fi
    
    # Terraform 초기화
    log_info "Terraform 초기화 중..."
    terraform init
    
    # 배포 단계별 실행
    deploy_phase1
    deploy_phase2
    deploy_phase3
    deploy_phase4
    deploy_phase5
    deploy_phase6
    deploy_phase7
    deploy_phase8
    deploy_phase9
    deploy_phase10
    
    log_success "🎉 Production 환경 배포가 완료되었습니다!"
    
    # 배포 정보 출력
    log_info "배포된 리소스 정보:"
    echo ""
    log_info "=== EKS 클러스터 정보 ==="
    terraform output eks_cluster_name 2>/dev/null || echo "EKS 클러스터 이름: N/A"
    terraform output eks_cluster_endpoint 2>/dev/null || echo "EKS 클러스터 엔드포인트: N/A"
    echo ""
    log_info "=== Jenkins 정보 ==="
    terraform output jenkins_alb_dns_name 2>/dev/null || echo "Jenkins ALB DNS: N/A"
    echo ""
    log_info "=== RDS 정보 ==="
    terraform output rds_endpoint 2>/dev/null || echo "RDS 엔드포인트: N/A"
    echo ""
    log_info "=== S3 버킷 정보 ==="
    terraform output airflow_logs_bucket_name 2>/dev/null || echo "Airflow 로그 버킷: N/A"
    terraform output spark_checkpoints_bucket_name 2>/dev/null || echo "Spark 체크포인트 버킷: N/A"
    echo ""
    log_info "=== VPN 정보 ==="
    terraform output vpn_setup_info 2>/dev/null || echo "VPN 설정 정보: N/A"
}

# 스크립트 실행
main "$@"
