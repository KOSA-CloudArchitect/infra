# AWS Load Balancer Controller

AWS Load Balancer Controller를 Helm으로 설치하는 방법입니다.

## 🚀 Helm 설치 (권장)

### 1. Helm Repository 추가
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

### 2. IAM 역할 생성
```bash
# 클러스터 OIDC 공급자 URL 확인
aws eks describe-cluster --name YOUR_CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text

# IAM 역할 생성 (OIDC URL을 실제 값으로 교체)
aws iam create-role \
  --role-name EKSLoadBalancerControllerRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/YOUR_OIDC_ID"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "oidc.eks.REGION.amazonaws.com/id/YOUR_OIDC_ID:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
            "oidc.eks.REGION.amazonaws.com/id/YOUR_OIDC_ID:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  }'
```

### 3. 필요한 정책 연결
```bash
aws iam attach-role-policy \
  --role-name EKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess

aws iam attach-role-policy \
  --role-name EKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name EKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

### 4. Helm으로 설치
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=YOUR_CLUSTER_NAME \
  --set region=YOUR_REGION \
  --set vpcId=YOUR_VPC_ID \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 5. ServiceAccount에 IAM 역할 연결
```bash
kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::YOUR_ACCOUNT_ID:role/EKSLoadBalancerControllerRole
```

### 6. Pod 재시작
```bash
kubectl delete pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## 📁 수동 설치 파일들

이 폴더에는 수동 설치용 파일들이 포함되어 있습니다 (참고용):

- `01-aws-load-balancer-controller-rbac.yaml` - RBAC 설정
- `02-aws-load-balancer-controller.yaml` - Controller Deployment

## ✅ 설치 확인

```bash
# Pod 상태 확인
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# 로그 확인
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## 🔧 트러블슈팅

### 자격 증명 오류
- IAM 역할이 올바르게 생성되었는지 확인
- ServiceAccount에 IAM 역할이 연결되었는지 확인
- OIDC 공급자가 클러스터에 등록되어 있는지 확인

### VPC ID 오류
- 올바른 VPC ID를 사용했는지 확인
- 클러스터가 해당 VPC에 있는지 확인
