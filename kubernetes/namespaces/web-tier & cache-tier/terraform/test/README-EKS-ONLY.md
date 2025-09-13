# EKS Cluster Only - Test Environment

이 파일은 test 환경에서 EKS 클러스터만 생성하기 위한 설정입니다.

## 🚀 **빠른 배포 방법**

### **1단계: Terraform 초기화**
```bash
cd terraform/test
terraform init
```

### **2단계: 배포 계획 확인**
```bash
terraform plan
```

### **3단계: EKS 클러스터 배포**
```bash
terraform apply
```

### **4단계: kubeconfig 설정**
```bash
# 배포 완료 후 출력된 명령어 실행
aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-test-eks
```

## 🏗️ **생성되는 리소스**

### **VPC 구성**
- **VPC**: `vpc-app-test-eks` (CIDR: 172.20.128.0/17)
- **Public Subnets**: 3개 AZ (172.20.128.0/20, 172.20.144.0/20, 172.20.160.0/20)
- **Private Subnets**: 3개 AZ (172.20.176.0/20, 172.20.192.0/20, 172.20.208.0/20)

### **EKS 클러스터**
- **클러스터명**: `hihypipe-test-eks`
- **Kubernetes 버전**: 1.33
- **노드 그룹**: `app-nodes` (t3.medium, 1-3개 노드)

### **IAM 설정**
- **Jenkins 역할**: `arn:aws:iam::890571109462:role/Jenkins-EKS-ECR-Role`
- **권한**: `system:masters` (클러스터 관리자)

### **EKS 애드온**
- CoreDNS
- kube-proxy
- AWS VPC CNI
- AWS Load Balancer Controller

## 🔒 **보안 설정**

- **노드 그룹**: Private subnet에 배치
- **IAM 역할**: OIDC 기반 서비스 계정
- **Jenkins 접근**: 시스템 마스터 권한으로 클러스터 관리 가능

## 💰 **비용 최적화**

- **노드 타입**: t3.medium (최소 사양)
- **노드 수**: 1개 (필요시 자동 확장)
- **NAT Gateway**: 단일 게이트웨이 사용

## 🧹 **정리 방법**

```bash
# 전체 인프라 삭제
terraform destroy

# 확인 후 yes 입력
```

## ⚠️ **주의사항**

1. **기존 private 환경과 격리**: 다른 CIDR 대역 사용
2. **Jenkins 역할**: 지정된 IAM 역할이 존재해야 함
3. **비용**: 테스트 완료 후 반드시 리소스 정리

## 🔧 **문제 해결**

### **kubectl 연결 실패**
```bash
# kubeconfig 재설정
aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-test-eks

# 클러스터 상태 확인
kubectl cluster-info
```

### **IAM 역할 매핑 문제**
```bash
# aws-auth ConfigMap 확인
kubectl get configmap aws-auth -n kube-system -o yaml

# IAM 역할 확인
aws iam get-role --role-name Jenkins-EKS-ECR-Role
```

## 📊 **모니터링**

```bash
# 노드 상태 확인
kubectl get nodes

# Pod 상태 확인
kubectl get pods -A

# 서비스 상태 확인
kubectl get services -A
```
