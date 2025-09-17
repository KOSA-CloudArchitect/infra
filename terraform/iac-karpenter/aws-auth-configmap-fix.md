# aws-auth ConfigMap 수정 가이드

## 중요: Terraform 적용 후 반드시 수행해야 하는 작업

Karpenter 노드가 EKS 클러스터에 조인하려면 aws-auth ConfigMap에 노드 IAM 역할을 추가해야 합니다.

## 1단계: 현재 aws-auth 백업

```bash
kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-backup.yaml
```

## 2단계: AWS Account ID와 Cluster Name 확인

```bash
# AWS Account ID 확인
aws sts get-caller-identity --query Account --output text

# Cluster Name 확인 (variables.tf에서 설정한 값)
echo "hihypipe-eks-cluster"  # 또는 terraform output으로 확인
```

## 3단계: aws-auth ConfigMap 편집

```bash
kubectl edit configmap aws-auth -n kube-system
```

## 4단계: mapRoles 섹션에 다음 항목 추가

기존 내용은 유지하고, 다음 항목을 추가하세요:

```yaml
data:
  mapRoles: |
    # 기존 노드그룹 역할들 (삭제하지 마세요)
    - rolearn: arn:aws:iam::<AWS_ACCOUNT_ID>:role/<existing-nodegroup-role>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    
    # 새로 추가할 Karpenter 노드 역할
    - rolearn: arn:aws:iam::<AWS_ACCOUNT_ID>:role/KarpenterNode-hihypipe-eks-cluster
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
```

## 5단계: 검증 및 모니터링

### 즉시 확인 명령어:

```bash
# 1. 생성된 인스턴스들 상태 확인
aws ec2 describe-instances \
  --filters "Name=tag:karpenter.sh/nodepool,Values=*" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,LaunchTime]' \
  --output table

# 2. Karpenter 로그 실시간 모니터링
kubectl logs -n karpenter deployment/karpenter -f | grep -i "node\|join\|bootstrap\|error"

# 3. 노드 조인 상태 확인
watch kubectl get nodes -l workload=core

# 4. aws-auth 설정 확인
kubectl get configmap aws-auth -n kube-system -o yaml | grep -A 10 "mapRoles"
```

### 테스트 파드 생성:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-node-join
spec:
  nodeSelector:
    workload: core
  containers:
  - name: test
    image: nginx:alpine
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
EOF
```

## 성공 지표:

- 새 노드가 2-3분 내에 `kubectl get nodes`에서 Ready 상태로 표시
- 과도한 인스턴스 생성 중단 (필요한 만큼만 생성)
- 테스트 파드가 새 노드에 정상 스케줄링

## 추가 문제 해결

### 만약 여전히 조인 실패 시:

#### 네트워크 설정 확인:

```bash
# 클러스터 보안그룹에 karpenter 태그 추가
CLUSTER_SG=$(aws eks describe-cluster --name hihypipe-eks-cluster --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
aws ec2 create-tags --resources $CLUSTER_SG --tags Key=karpenter.sh/discovery,Value=hihypipe-eks-cluster

# 서브넷 태그 확인
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=hihypipe-eks-cluster"
```

#### 실패한 인스턴스 직접 진단:

```bash
# 인스턴스 콘솔 로그 확인
aws ec2 get-console-output --instance-id <instance-id> --output text | tail -n 100
```

#### 불필요한 인스턴스 정리:

```bash
# 클러스터에 조인되지 않은 Karpenter 인스턴스들 확인 후 수동 종료
aws ec2 describe-instances \
  --filters "Name=tag:karpenter.sh/nodepool,Values=*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' --output text

# 확인 후 종료 (주의: 수동 확인 필수)
# aws ec2 terminate-instances --instance-ids <instance-id-1> <instance-id-2>
```



