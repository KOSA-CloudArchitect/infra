# hihypipe EKS 인프라 - Private Subnet 구성

## 📋 개요

이 폴더는 **Private Subnet 기반의 EKS 클러스터**를 구성하는 Terraform 코드입니다. 보안성이 높고 격리된 환경에서 EKS를 운영하고자 할 때 사용합니다.

## 🏗️ 아키텍처

```
Internet
    │
    ▼
┌─────────────────┐
│  Bastion Host   │ ← 별도 구성 필요
└─────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    VPC-APP                             │
│  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │  Public Subnet  │  │      Private Subnets        │  │
│  │   (Bastion)     │  │   (EKS Nodes + Apps)       │  │
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

### **🔒 보안 중심 설계**
- **EKS 노드**: Private Subnet에 배치
- **NAT Gateway**: 외부 인터넷 접근을 위한 통로
- **VPC 격리**: App과 DB VPC 완전 분리
- **Bastion Host**: 별도 구성 필요 (이 코드에는 포함되지 않음)

### **💰 비용 구조**
- **NAT Gateway**: 활성화 (시간당 비용 발생)
- **EKS 노드**: Private Subnet (보안성 향상)
- **VPC Endpoints**: 선택적 사용

### **🌐 네트워크 구성**
- **VPC-APP**: Public + Private Subnet
- **VPC-DB**: Private Subnet만 (완전 격리)
- **VPC Peering**: App ↔ DB 간 통신
- **Route Tables**: 자동 구성

## 📁 파일 구조

```
terraform_private/
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

# eks만 배포 실행
# variables.tf에 create_eks = true/false 확인
terraform apply -target=module.eks
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
- **Bastion Host**: 별도 구성 필요 (이 코드에는 포함되지 않음)
- **Private Subnet**: 외부에서 직접 접근 불가
- **NAT Gateway**: 비용 발생 (시간당 과금)

### **🌐 네트워크 제한사항**
- **외부 접근**: NAT Gateway를 통해서만 가능
- **EKS API**: Private Subnet에서만 접근 가능
- **인터넷 연결**: NAT Gateway를 통한 우회 필요

### **💰 비용 고려사항**
- **NAT Gateway**: 시간당 비용 발생
- **데이터 전송**: NAT Gateway를 통한 트래픽 비용
- **EKS 노드**: Private Subnet 배치로 보안성 향상

## 🔧 구성 옵션

### **VPC 설정**
```hcl
# VPC-APP
enable_nat_gateway = true      # NAT Gateway 활성화
single_nat_gateway = true      # 단일 NAT Gateway (비용 절약)

# VPC-DB
create_igw = false             # Internet Gateway 비활성화
enable_nat_gateway = false     # NAT Gateway 비활성화
```

### **EKS 설정**
```hcl
# Private Subnet 사용
subnet_ids = module.vpc_app.private_subnets

# Public Endpoint 비활성화 (기본값)
# endpoint_public_access = false
```

## 📊 비용 예상

### **월별 예상 비용 (ap-northeast-2)**
- **NAT Gateway**: ~$45/월 (시간당 $0.0625)
- **EKS 노드 (t3.medium)**: ~$30/월 × 노드 수
- **데이터 전송**: 사용량에 따라 변동
- **총 예상**: ~$75-150/월 (노드 수에 따라)

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
    subnet_ids     = module.vpc_app.private_subnets
  }
}
```

### **VPC Endpoints 추가**
```hcl
# 필요한 경우 VPC Endpoints 추가
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc_app.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
}
```

## 🆚 Public vs Private 비교

| 구분 | Private (이 구성) | Public |
|------|-------------------|---------|
| **보안성** | 🔒 높음 | ⚠️ 보통 |
| **비용** | 💰 높음 (NAT Gateway) | 💰 낮음 |
| **외부 접근** | 🔄 NAT Gateway 우회 | 🌐 직접 접근 |
| **관리 복잡도** | 🔧 복잡 | 🟢 간단 |
| **프로덕션 적합성** | ✅ 높음 | ⚠️ 보통 |

## 📞 지원 및 문의

프로젝트 관련 문의사항이 있으시면 팀에 연락해주세요.

---

**프로젝트**: hihypipe EKS 인프라  
**환경**: Private Subnet 구성  
**버전**: 1.0  
**최종 업데이트**: 2024년 8월 23일
