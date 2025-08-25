# hihypipe EKS 인프라 - Public Subnet 구성

## 📋 개요

이 폴더는 **Public Subnet 기반의 EKS 클러스터**를 구성하는 Terraform 코드입니다. 비용 절약과 간단한 구성을 우선시하며, 빠른 테스트와 개발 환경에 적합합니다.

## 🏗️ 아키텍처

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    VPC-APP                             │
│  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │  Public Subnets │  │      Private Subnets        │  │
│  │   (EKS Nodes)   │  │      (Future Apps)          │  │
│  │                 │  │                             │  │
│  │  Internet       │  │  ┌─────────────────────┐    │  │
│  │  Gateway        │  │  │   EKS Cluster       │    │  │
│  │                 │  │  │                     │    │  │
│  │                 │  │  │  ┌───────────────┐  │    │  │
│  │                 │  │  │  │  Node Group   │  │    │  │
│  │                 │  │  │  │  (t3.medium)  │  │    │  │
│  │                 │  │  │  └───────────────┘  │    │  │
│  └─────────────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                    VPC-DB                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Private Subnets                        │ │
│  │              (Database Only)                        │ │
│  │                                                     │ │
│  │  ┌─────────────────────────────────────────────┐   │ │
│  │  │              RDS Subnet Group               │   │ │
│  │  │              (AZ-a, AZ-b)                   │   │ │
│  │  └─────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## ✨ 주요 특징

### **💰 비용 최적화**
- **NAT Gateway 비활성화**: 월 비용 절약 (~$45/월)
- **EKS 노드**: Public Subnet에 직접 배치
- **외부 인터넷 접근**: 직접 연결로 VPC Endpoints 불필요
- **간단한 네트워크 구성**: 복잡한 라우팅 설정 불필요

### **🚀 빠른 배포**
- **간단한 구성**: 최소한의 설정으로 빠른 배포
- **자동 설정**: EKS 모듈이 모든 설정을 자동 처리
- **직접 접근**: 외부에서 EKS API 직접 접근 가능

### **🌐 네트워크 구성**
- **VPC-APP**: Public + Private Subnet
- **VPC-DB**: Private Subnet만 (완전 격리)
- **VPC Peering**: App ↔ DB 간 통신
- **Route Tables**: 자동 구성

## 📁 파일 구조

```
terraform_public/
├── main.tf                    # VPC, Security Groups, VPC Peering
├── eks.tf                     # EKS Cluster 및 Node Groups
├── variables.tf               # 변수 정의
├── outputs.tf                 # 출력값 정의
├── terraform.tfvars.example   # 변수 예시 파일
├── README.md                  # 이 파일
└── EKS_DEPLOYMENT_ANALYSIS.md # 배포 분석 보고서
```

## 🚀 시작하기

### **1. 사전 요구사항**
```bash
# AWS CLI 설정
aws configure

# Terraform 설치 (>= 1.0)
terraform version
```

### **2. 변수 설정**
```bash
# 예시 파일을 복사하여 실제 값으로 수정
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 파일 편집
vim terraform.tfvars
```

### **3. 배포 실행**
```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포 실행
terraform apply
```

### **4. EKS 접근**
```bash
# kubeconfig 업데이트
aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-cluster

# 클러스터 상태 확인
kubectl get nodes
kubectl get pods --all-namespaces
```

## ⚠️ 주의사항

### **🔐 보안 고려사항**
- **Public Subnet**: EKS 노드가 외부 인터넷에 직접 노출
- **Public Endpoint**: EKS API가 외부에서 접근 가능
- **보안 그룹**: 적절한 인바운드 규칙 설정 필요
- **프로덕션 환경**: 추가 보안 설정 권장

### **🌐 네트워크 장점**
- **외부 접근**: NAT Gateway 없이 직접 인터넷 접근
- **EKS API**: 외부에서 직접 접근 가능
- **간단한 구성**: 복잡한 VPC Endpoints 설정 불필요

### **💰 비용 절약**
- **NAT Gateway**: 비활성화로 월 $45+ 절약
- **VPC Endpoints**: 불필요로 추가 비용 절약
- **데이터 전송**: 직접 연결로 우회 비용 없음

## 🔧 구성 옵션

### **VPC 설정**
```hcl
# VPC-APP
enable_nat_gateway = false     # NAT Gateway 비활성화
create_igw = true              # Internet Gateway 활성화
map_public_ip_on_launch = true # Public IP 자동 할당

# VPC-DB
create_igw = false             # Internet Gateway 비활성화
enable_nat_gateway = false     # NAT Gateway 비활성화
```

### **EKS 설정**
```hcl
# Public Subnet 사용
subnet_ids = module.vpc_app.public_subnets

# Public Endpoint 활성화
endpoint_public_access = true

# 클러스터 생성자 권한
enable_cluster_creator_admin_permissions = true
```

## 📊 비용 예상

### **월별 예상 비용 (ap-northeast-2)**
- **NAT Gateway**: $0/월 (비활성화)
- **EKS 노드 (t3.medium)**: ~$30/월 × 노드 수
- **데이터 전송**: 사용량에 따라 변동
- **총 예상**: ~$30-90/월 (노드 수에 따라)

### **비용 절약 효과**
- **NAT Gateway 제거**: 월 $45+ 절약
- **VPC Endpoints 제거**: 월 $7+ 절약
- **총 절약**: 월 $50+ 절약

## 🚀 확장 및 수정

### **노드 그룹 추가**
```hcl
eks_managed_node_groups = {
  app-nodes = {
    # 기존 설정...
  }
  
  # 새로운 노드 그룹 추가
  worker-nodes = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["t3.large"]
    min_size       = 2
    max_size       = 5
    desired_size   = 2
    subnet_ids     = module.vpc_app.public_subnets
  }
}
```

### **보안 그룹 강화**
```hcl
# EKS 노드용 보안 그룹 추가
resource "aws_security_group" "eks_nodes" {
  name_prefix = "eks-nodes"
  vpc_id      = module.vpc_app.vpc_id
  
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["YOUR_IP/32"]  # 특정 IP만 허용
  }
}
```

## 🆚 Public vs Private 비교

| 구분 | Public (이 구성) | Private |
|------|------------------|---------|
| **보안성** | ⚠️ 보통 | 🔒 높음 |
| **비용** | 💰 낮음 | 💰 높음 (NAT Gateway) |
| **외부 접근** | 🌐 직접 접근 | 🔄 NAT Gateway 우회 |
| **관리 복잡도** | 🟢 간단 | 🔧 복잡 |
| **개발/테스트 적합성** | ✅ 높음 | ⚠️ 보통 |

## 🔒 보안 강화 권장사항

### **프로덕션 환경 사용 시**
1. **IP 제한**: 특정 IP에서만 EKS API 접근 허용
2. **보안 그룹**: 최소한의 포트만 열기
3. **IAM 정책**: 세밀한 권한 제어
4. **모니터링**: CloudTrail, CloudWatch 로그 활성화

### **개발/테스트 환경**
1. **빠른 배포**: 간단한 설정으로 빠른 구성
2. **비용 절약**: NAT Gateway 없이 운영
3. **직접 접근**: 외부에서 kubectl 명령 실행 가능

## 🚨 제한사항

### **보안 제한**
- **외부 노출**: EKS 노드가 Public Subnet에 위치
- **API 접근**: 외부에서 EKS API 직접 접근 가능
- **네트워크 보안**: 추가적인 보안 설정 필요

### **운영 제한**
- **프로덕션 환경**: 추가 보안 설정 후 사용 권장
- **규정 준수**: 보안 정책에 따라 사용 제한 가능
- **모니터링**: 외부 접근에 대한 지속적 모니터링 필요

## 📞 지원 및 문의

프로젝트 관련 문의사항이 있으시면 팀에 연락해주세요.

---

**프로젝트**: hihypipe EKS 인프라  
**환경**: Public Subnet 구성  
**버전**: 1.0  
**최종 업데이트**: 2024년 8월 23일
