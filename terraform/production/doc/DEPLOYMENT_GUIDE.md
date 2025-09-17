# 🚀 Production 환경 배포 가이드

## 📋 개요
이 문서는 production 환경을 안전하고 체계적으로 배포하는 방법을 설명합니다.

## 🏗️ 인프라 구성 요소

### **핵심 컴포넌트**
- **EKS 클러스터**: Kubernetes 1.33
- **VPC**: APP VPC (172.20.0.0/16) + DB VPC (172.21.0.0/16)
- **RDS**: PostgreSQL 17.6 (Single-AZ, 테스트용)
- **S3**: Airflow 로그 + Spark 체크포인트
- **Jenkins**: CI/CD 서버 (ALB + EC2)
- **EBS CSI Driver**: Helm 차트로 설치
- **VPN**: Site-to-Site VPN 연결

### **노드 그룹 구성**
| 노드 그룹 | 용도 | 인스턴스 타입 | 최소/최대/희망 | 용량 타입 |
|-----------|------|---------------|----------------|------------|
| `core-on` | 시스템 핵심 | m7g.large | 1/10/1 | On-Demand |
| `airflow-core-on` | Airflow 스케줄러 | m7g.large | 1/10/1 | On-Demand |
| `airflow-worker-spot` | Airflow 워커 | m7g.large~2xlarge | 1/20/1 | Spot |
| `spark-driver-on` | Spark 드라이버 | m7g.large | 1/10/1 | On-Demand |
| `spark-exec-spot` | Spark 실행자 | m7g.large~4xlarge | 1/100/1 | Spot |
| `kafka-storage-on` | Kafka 브로커 | m7g.large | 1/10/1 | On-Demand |
| `gpu-spot` | GPU 워크로드 | g5.xlarge~4xlarge | 0/20/0 | Spot |

## 🚀 자동 배포 (권장)

### **1단계: 사전 준비**
```bash
# AWS CLI 설정
aws configure

# 필요한 도구 설치
brew install terraform kubectl helm

# 프로젝트 디렉토리로 이동
cd /Users/tjpark/Documents/GitHub/infra/terraform/production
```

### **2단계: 자동 배포 실행**
```bash
# 전체 인프라 자동 배포
./deploy.sh
```

**배포 시간**: 약 4-6시간 (모든 단계 포함)

## 🔄 수동 배포 (단계별)

### **Phase 1: 기본 인프라 (30분)**
```bash
terraform init
terraform plan

# VPC 및 네트워킹
terraform apply -target=module.vpc_app -auto-approve
terraform apply -target=module.vpc_db -auto-approve
terraform apply -target=aws_vpc_peering_connection.app_to_db -auto-approve
terraform apply -target=aws_route.app_to_db -auto-approve
terraform apply -target=aws_route.db_to_app -auto-approve
```

**✅ 검증 사항:**
- VPC가 정상 생성되었는지 확인
- VPC 피어링 연결 상태 확인
- 서브넷이 각 AZ에 올바르게 생성되었는지 확인

### **Phase 2: 보안 및 IAM (30분)**
```bash
# IAM 역할 및 정책 생성
terraform apply -target=aws_iam_role.jenkins_role -auto-approve
terraform apply -target=aws_iam_role.ebs_csi_driver -auto-approve
terraform apply -target=aws_iam_role.cni_role -auto-approve
terraform apply -target=aws_iam_role.cluster_autoscaler -auto-approve
terraform apply -target=aws_iam_role.airflow_irsa -auto-approve
terraform apply -target=aws_iam_role.spark_irsa -auto-approve

# IAM 정책 및 첨부
terraform apply -target=aws_iam_policy.jenkins_policy -auto-approve
terraform apply -target=aws_iam_policy.cluster_autoscaler_policy -auto-approve
terraform apply -target=aws_iam_policy.airflow_s3_policy -auto-approve
terraform apply -target=aws_iam_policy.spark_s3_policy -auto-approve
terraform apply -target=aws_iam_role_policy_attachment.jenkins_policy_attachment -auto-approve
terraform apply -target=aws_iam_role_policy_attachment.ebs_csi_driver_policy -auto-approve
terraform apply -target=aws_iam_role_policy_attachment.cni_policy_attachment -auto-approve
terraform apply -target=aws_iam_role_policy_attachment.cluster_autoscaler_policy_attachment -auto-approve
terraform apply -target=aws_iam_role_policy_attachment.airflow_s3_policy_attachment -auto-approve
terraform apply -target=aws_iam_role_policy_attachment.spark_s3_policy_attachment -auto-approve
terraform apply -target=aws_iam_instance_profile.jenkins_instance_profile -auto-approve
```

**✅ 검증 사항:**
- Jenkins 역할이 올바른 권한을 가지고 있는지 확인
- EBS CSI Driver 역할이 생성되었는지 확인
- IRSA 역할들이 올바른 Trust Policy를 가지고 있는지 확인

### **Phase 3: 데이터베이스 (1시간)**
```bash
# RDS 데이터베이스 생성
terraform apply -target=aws_db_subnet_group.rds_subnet_group -auto-approve
terraform apply -target=aws_security_group.rds_sg -auto-approve
terraform apply -target=aws_db_instance.airflow_db -auto-approve
```

**✅ 검증 사항:**
- RDS 인스턴스가 정상 생성되었는지 확인
- 백업 설정이 올바른지 확인
- 보안 그룹이 올바르게 설정되었는지 확인

### **Phase 4: 스토리지 (30분)**
```bash
# S3 버킷 생성 및 설정
terraform apply -target=aws_s3_bucket.airflow_logs -auto-approve
terraform apply -target=aws_s3_bucket.spark_checkpoints -auto-approve
terraform apply -target=aws_s3_bucket_versioning.airflow_logs_versioning -auto-approve
terraform apply -target=aws_s3_bucket_versioning.spark_checkpoints_versioning -auto-approve
terraform apply -target=aws_s3_bucket_server_side_encryption_configuration.airflow_logs_encryption -auto-approve
terraform apply -target=aws_s3_bucket_server_side_encryption_configuration.spark_checkpoints_encryption -auto-approve
terraform apply -target=aws_s3_bucket_lifecycle_configuration.airflow_logs_lifecycle -auto-approve
terraform apply -target=aws_s3_bucket_lifecycle_configuration.spark_checkpoints_lifecycle -auto-approve
terraform apply -target=aws_s3_bucket_public_access_block.airflow_logs_pab -auto-approve
terraform apply -target=aws_s3_bucket_public_access_block.spark_checkpoints_pab -auto-approve
```

**✅ 검증 사항:**
- S3 버킷이 올바른 권한으로 생성되었는지 확인
- 라이프사이클 정책이 설정되었는지 확인
- 퍼블릭 액세스가 차단되었는지 확인

### **Phase 5: EKS 클러스터 (2-3시간)**
```bash
# EKS 클러스터 생성
terraform apply -target=module.eks -auto-approve

# EKS 퍼블릭 액세스 제한
terraform apply -target=null_resource.restrict_eks_public_access -auto-approve
```

**✅ 검증 사항:**
- EKS 클러스터가 정상 생성되었는지 확인
- 모든 애드온이 ACTIVE 상태인지 확인
- 퍼블릭 액세스가 현재 IP로 제한되었는지 확인

### **Phase 6: 노드 그룹 (1-2시간)**
```bash
# 핵심 노드 그룹 생성
terraform apply -target=module.eks.eks_managed_node_groups.core_on -auto-approve
terraform apply -target=module.eks.eks_managed_node_groups.airflow_core_on -auto-approve
terraform apply -target=module.eks.eks_managed_node_groups.spark_driver_on -auto-approve
terraform apply -target=module.eks.eks_managed_node_groups.kafka_storage_on -auto-approve

# Spot 노드 그룹 생성
terraform apply -target=module.eks.eks_managed_node_groups.airflow_worker_spot -auto-approve
terraform apply -target=module.eks.eks_managed_node_groups.spark_exec_spot -auto-approve
terraform apply -target=module.eks.eks_managed_node_groups.gpu_spot -auto-approve
```

**✅ 검증 사항:**
- 모든 노드가 Ready 상태인지 확인
- 노드 라벨이 올바르게 설정되었는지 확인
- 클러스터 오토스케일러가 정상 작동하는지 확인

### **Phase 7: VPN 연결 (1시간)**
```bash
# VPN Gateway 생성
terraform apply -target=aws_vpn_gateway.aws_vgw -auto-approve

# Customer Gateway 생성
terraform apply -target=aws_customer_gateway.onprem_cgw -auto-approve

# VPN Connection 생성
terraform apply -target=aws_vpn_connection.aws_to_onprem -auto-approve

# VPN Route 설정
terraform apply -target=aws_vpn_connection_route.aws_to_onprem_route -auto-approve
```

**✅ 검증 사항:**
- VPN Gateway가 정상 생성되었는지 확인
- Customer Gateway가 올바른 IP로 설정되었는지 확인
- VPN Connection이 UP 상태인지 확인
- 라우팅 테이블에 VPN 경로가 추가되었는지 확인

### **Phase 8: Jenkins 서버 (1시간)**
```bash
# Jenkins 보안 그룹 생성
terraform apply -target=aws_security_group.alb_sg -auto-approve
terraform apply -target=aws_security_group.jenkins_sg -auto-approve

# Jenkins ALB 생성
terraform apply -target=aws_lb.jenkins_alb -auto-approve
terraform apply -target=aws_lb_target_group.jenkins_tg -auto-approve
terraform apply -target=aws_lb_listener.jenkins_listener -auto-approve

# Jenkins 서버 생성
terraform apply -target=aws_instance.jenkins_controller -auto-approve
terraform apply -target=aws_lb_target_group_attachment.jenkins_attachment -auto-approve
```

**✅ 검증 사항:**
- Jenkins 서버가 정상 시작되었는지 확인
- ALB를 통해 Jenkins에 접근할 수 있는지 확인
- EKS 클러스터에 접근할 수 있는지 확인

### **Phase 9: Kubernetes 리소스 (30분)**
```bash
# kubectl 연결 설정
aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-eks-cluster

# terraform.tfvars에서 create_k8s_resources = true로 변경
sed -i.bak 's/create_k8s_resources = false/create_k8s_resources = true/' terraform.tfvars

# EBS CSI Driver 설치 (kubectl 연결 후)
terraform apply -target=helm_release.ebs_csi_driver -auto-approve

# Kubernetes 네임스페이스 및 서비스 어카운트 생성
terraform apply -target=kubernetes_namespace.airflow -auto-approve
terraform apply -target=kubernetes_namespace.spark -auto-approve
terraform apply -target=kubernetes_service_account.airflow_irsa -auto-approve
terraform apply -target=kubernetes_service_account.spark_irsa -auto-approve
```

**✅ 검증 사항:**
- kubectl이 클러스터에 연결되었는지 확인
- EBS CSI Driver가 정상 설치되었는지 확인
- 네임스페이스가 생성되었는지 확인
- 서비스 어카운트가 IRSA와 연결되었는지 확인

### **Phase 10: 최종 검증 (30분)**
```bash
# 전체 인프라 검증
terraform apply -auto-approve

# 클러스터 상태 확인
kubectl get nodes
kubectl get pods -A
kubectl get namespaces
```

## 🔧 사전 준비사항

### **1. AWS CLI 설정**
```bash
aws configure
# AWS Access Key ID: [입력]
# AWS Secret Access Key: [입력]
# Default region name: ap-northeast-2
# Default output format: json
```

### **2. kubectl 설치 및 설정**
```bash
# kubectl 설치 (macOS)
brew install kubectl

# EKS 클러스터 연결
aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-eks-cluster
```

### **3. Helm 설치**
```bash
# Helm 설치 (macOS)
brew install helm
```

### **4. Terraform 설치**
```bash
# Terraform 설치 (macOS)
brew install terraform
```

## ⚠️ 주의사항

### **보안 고려사항**
- EKS 퍼블릭 액세스는 현재 IP만 허용
- RDS는 Private 서브넷에 배치
- S3 버킷은 퍼블릭 액세스 차단
- 모든 리소스에 적절한 태그 적용
- Jenkins는 ALB를 통해서만 접근 가능

### **비용 최적화**
- Spot 인스턴스 활용으로 비용 절약
- 클러스터 오토스케일러로 자동 스케일링
- S3 라이프사이클 정책으로 스토리지 비용 절약
- Single-AZ RDS로 비용 절약 (테스트 환경)

### **모니터링**
- ~~CloudWatch 로그 활성화~~ (비활성화됨)
- ~~EKS 클러스터 메트릭 수집~~ (비활성화됨)
- ~~RDS 성능 인사이트 활성화~~ (비활성화됨)

## 🚨 문제 해결

### **일반적인 문제**
1. **EKS 애드온 DEGRADED**: `resolve_conflicts = "OVERWRITE"` 설정 확인
2. **노드 스케줄링 실패**: 테인트 설정 확인
3. **IRSA 연결 실패**: OIDC 프로바이더 확인
4. **EBS 볼륨 마운트 실패**: EBS CSI Driver 상태 확인
5. **Kubernetes 리소스 생성 실패**: kubectl 연결 상태 확인

### **롤백 절차**
```bash
# 특정 리소스 삭제
terraform destroy -target=module.eks.eks_managed_node_groups.core_on

# 전체 환경 삭제 (주의!)
terraform destroy
```

### **상태 파일 문제 해결**
```bash
# Kubernetes 리소스 상태에서 제거
terraform state rm helm_release.ebs_csi_driver[0]
terraform state rm kubernetes_namespace.airflow[0]
terraform state rm kubernetes_namespace.spark[0]
terraform state rm kubernetes_service_account.airflow_irsa[0]
terraform state rm kubernetes_service_account.spark_irsa[0]
```

## 📊 예상 비용 (월간)

| 컴포넌트 | 예상 비용 (USD) |
|----------|----------------|
| EKS 클러스터 | $73 |
| 노드 그룹 (On-Demand) | $200-400 |
| 노드 그룹 (Spot) | $50-150 |
| RDS (Single-AZ) | $75-150 |
| S3 스토리지 | $10-50 |
| Jenkins (ALB + EC2) | $50-100 |
| VPN Gateway | $36 |
| **총 예상 비용** | **$494-959** |

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. Terraform 상태: `terraform show`
2. EKS 클러스터 상태: `kubectl get nodes`
3. AWS 콘솔에서 리소스 상태 확인
4. ~~CloudWatch 로그 확인~~ (비활성화됨)
5. `TROUBLESHOOTING.md` 파일 참조

## 🔗 관련 문서

- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - 문제 해결 가이드
- [MANUAL_FIX.md](../MANUAL_FIX.md) - 수동 문제 해결 방법
- [deploy.sh](../deploy.sh) - 자동 배포 스크립트
- [deploy-eks.sh](../deploy-eks.sh) - EKS 전용 배포 스크립트

---
**작성일**: 2024년 12월  
**작성자**: tjpark  
**환경**: Production  
**최종 업데이트**: 2024년 12월 7일