# Infrastructure as Code - Terraform

이 프로젝트는 AWS 인프라를 Terraform으로 관리하는 코드입니다.

## 폴더 구조

- `public/`: 공개 서브넷이 포함된 VPC 구성 (EKS 클러스터 포함 가능)
- `private/`: 프라이빗 서브넷 중심의 VPC 구성 (EKS 클러스터 포함 가능)

## 주요 구성 요소

### VPC 구성
- **VPC-APP**: 애플리케이션용 VPC (공개/프라이빗 서브넷 포함)
- **VPC-DB**: 데이터베이스용 VPC (프라이빗 서브넷만)
- **VPC Peering**: APP과 DB VPC 간 통신

### EKS 클러스터 (선택사항)
- EKS 클러스터와 관리형 노드 그룹
- `create_eks_cluster` 변수로 생성 여부 제어

## 배포 방법

### 1. EKS 모듈을 제외한 기본 인프라 배포

```bash
# public 폴더에서
cd terraform/public
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에서 create_eks_cluster = false로 설정
terraform init
terraform plan
terraform apply

# private 폴더에서
cd terraform/private
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에서 create_eks_cluster = false로 설정
terraform init
terraform plan
terraform apply
```

### 2. EKS 클러스터를 포함한 전체 배포

```bash
# terraform.tfvars에서 create_eks_cluster = true로 설정
terraform plan
terraform apply
```

## 주요 변수

### EKS 제어
- `create_eks_cluster`: EKS 클러스터 생성 여부 (boolean)
- `eks_cluster_name`: EKS 클러스터 이름

### 네트워크 설정
- `aws_region`: AWS 리전
- `vpc_app_cidr`: VPC-APP CIDR 블록
- `vpc_db_cidr`: VPC-DB CIDR 블록
- `availability_zones`: 가용영역 목록

## 최근 수정 사항

### EKS 모듈 조건부 생성
- `count = var.create_eks_cluster ? 1 : 0` 추가
- EKS 모듈을 제외한 배포 가능

### Output 수정
- EKS 관련 output을 조건부로 출력
- 존재하지 않는 리소스 참조 제거

### 변수 추가
- `create_eks_cluster` 변수로 EKS 생성 제어

## 주의사항

1. **비용 최적화**: NAT Gateway는 private 폴더에서만 활성화
2. **보안**: VPC-DB는 완전 격리 (IGW, NAT Gateway 없음)
3. **EKS 배포**: `create_eks_cluster = true`로 설정해야 EKS 리소스 생성

## 문제 해결

### 일반적인 에러
- **"module.eks is a list of objects"**: `create_eks_cluster` 변수 확인
- **"aws_db_subnet_group.rds not declared"**: RDS 서브넷 그룹이 정의되지 않음

### 해결 방법
1. `terraform.tfvars`에서 `create_eks_cluster = false` 설정
2. EKS 모듈 없이 기본 인프라만 배포
3. 필요시 EKS 모듈을 별도로 활성화
