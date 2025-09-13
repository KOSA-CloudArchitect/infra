# 03-Networking (네트워킹)

이 폴더에는 네트워킹 관련 리소스들이 포함되어 있습니다.

## 📁 폴더 구조

- `aws-load-balancer-controller/` - AWS Load Balancer Controller (Helm 설치)
- `03-network-policies-basic.yaml` - 기본 네트워크 정책
- `04-network-policies-advanced.yaml` - 고급 네트워크 정책
- `05-loadbalancer-services.yaml` - LoadBalancer 타입 서비스
- `06-ingress-resources.yaml` - Ingress 리소스 (ALB)
- `07-frontend-nodeport.yaml` - NodePort 서비스 (개발용)

## 🚀 배포 순서

### 1. AWS Load Balancer Controller 설치 (Helm)
```bash
# Helm repository 추가
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# IAM 역할 생성 및 정책 연결 (aws-load-balancer-controller/README.md 참조)
# Controller 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=YOUR_CLUSTER_NAME \
  --set region=YOUR_REGION \
  --set vpcId=YOUR_VPC_ID
```

### 2. 네트워크 정책 적용
```bash
kubectl apply -f 03-network-policies-basic.yaml
kubectl apply -f 04-network-policies-advanced.yaml
```

### 3. LoadBalancer 서비스 생성
```bash
kubectl apply -f 05-loadbalancer-services.yaml
```

### 4. Ingress 리소스 배포
```bash
kubectl apply -f 06-ingress-resources.yaml
```

## ⚠️ 중요 사항

- AWS Load Balancer Controller는 **Helm으로 설치**하는 것을 권장합니다
- 수동 설치 파일들은 `aws-load-balancer-controller/` 폴더에 참고용으로 보관
- IAM 역할 설정이 필요합니다 (자세한 내용은 해당 폴더의 README 참조)
