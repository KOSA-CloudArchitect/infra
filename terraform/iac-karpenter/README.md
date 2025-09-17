# Karpenter LLM ARM64 온디맨드 구성

이 프로젝트는 **기존 EKS 클러스터를 절대 변경하지 않고** 별도 Terraform state에서 Karpenter만 안전하게 추가하여 LLM 워크로드를 위한 ARM64 온디맨드 노드를 자동 프로비저닝하는 구성입니다.

## ⚠️ 중요 주의사항

- **기존 EKS/노드그룹과 완전 분리된 별도 Terraform state**
- **기존 모듈 참조 금지** - 오직 data 소스만 사용
- **단계적 적용 필수** - `-target` 옵션으로 신규 리소스만 순차 적용

## 구성 요소

- **providers.tf**: Terraform 및 Provider 구성 (data 소스 기반)
- **variables.tf**: 변수 정의 및 기본값
- **iam.tf**: Karpenter 컨트롤러 및 노드용 IAM 역할/정책
- **helm_karpenter.tf**: Karpenter Helm 차트 설치
- **awsnodetemplate_llm.tf**: LLM 워크로드용 AWSNodeTemplate
- **provisioner_llm.tf**: LLM 전용 Provisioner (t4g.medium ARM64 온디맨드)
- **kubernetes_llm_deploy.yaml**: LLM 모델 배포 예시
- **kubernetes_llm_pdb.yaml**: Pod Disruption Budget

## 사전 준비

### 1. 변수 설정
`variables.tf`에서 다음 값들을 확인/변경:
```hcl
variable "cluster_name" {
  default = "hihypipe-eks-cluster"  # 실제 클러스터명 (이미 설정됨)
}
```

### 2. EKS 클러스터 태그 확인
기존 EKS 클러스터의 서브넷과 보안그룹에 다음 태그가 있는지 확인:
- 서브넷: `karpenter.sh/discovery = hihypipe-eks-cluster` ✅ (App Private 서브넷 3개만 설정됨)
- 보안그룹: `aws:eks:cluster-name = hihypipe-eks-cluster` ✅ (이미 설정됨)

**안전한 서브넷 구성:**
- ✅ `subnet-0457482d8fd4633d2` (hihypipe-vpc-app-private-ap-northeast-2a)
- ✅ `subnet-0f8d75c0597802e40` (hihypipe-vpc-app-private-ap-northeast-2b)  
- ✅ `subnet-0a20dabe898695929` (hihypipe-vpc-app-private-ap-northeast-2c)
- ❌ DB Private 서브넷 제외 (데이터베이스 보안)
- ❌ Public 서브넷 제외 (보안상 위험)



### 3. 로컬 State 파일 관리
이 프로젝트는 로컬 state 파일(`terraform.tfstate`)을 사용합니다:
- State 파일은 `iac-karpenter/` 디렉토리에 생성됩니다
- State 파일을 백업해 두시기 바랍니다
- 다른 환경에서 작업할 때는 State 파일을 공유해야 합니다

## 적용 순서 (단계별 필수)

### 1단계: IAM 리소스 생성
```bash
# IAM 역할 및 정책 생성
terraform plan -target=aws_iam_role.karpenter_controller
terraform plan -target=aws_iam_role.karpenter_node
terraform plan -target=aws_iam_instance_profile.karpenter_node

terraform apply -target=aws_iam_role.karpenter_controller
terraform apply -target=aws_iam_role.karpenter_node
terraform apply -target=aws_iam_instance_profile.karpenter_node
```

### 2단계: Karpenter Helm 차트 설치
```bash
# Karpenter 컨트롤러 설치 (0.37)
terraform plan -target=helm_release.karpenter
terraform apply -target=helm_release.karpenter
```

### 3단계: AWSNodeTemplate 및 Provisioner 생성
```bash
# AWSNodeTemplate 생성
terraform plan -target=kubernetes_manifest.karpenter_awsnodetemplate_llm
terraform apply -target=kubernetes_manifest.karpenter_awsnodetemplate_llm

# Provisioner 생성
terraform plan -target=kubernetes_manifest.karpenter_provisioner_llm
terraform apply -target=kubernetes_manifest.karpenter_provisioner_llm
```

### 4단계: LLM 워크로드 배포
```bash
# PDB 먼저 적용
kubectl apply -f kubernetes_llm_pdb.yaml

# LLM 배포 적용
kubectl apply -f kubernetes_llm_deploy.yaml
```

## 검증 명령

### Karpenter 상태 확인
```bash
# Karpenter 컨트롤러 로그
kubectl -n karpenter logs deploy/karpenter

# Provisioner 상태
kubectl get provisioner llm-arm-ondemand

# AWSNodeTemplate 상태
kubectl get awsnodetemplate llm-arm-ondemand
```

### 노드 확인
```bash
# ARM64 LLM 노드 확인
kubectl get nodes -L workload,kubernetes.io/arch

# 노드 상세 정보
kubectl describe nodes -l workload=llm-model
```

### 파드 확인
```bash
# LLM 파드 상태 확인
kubectl get pods -o wide -l app=llm-model

# 파드 로그 확인
kubectl logs -l app=llm-model
```

## 주요 특징

### LLM 전용 노드 구성
- **인스턴스 타입**: t4g.medium (ARM64)
- **용량 타입**: 온디맨드만
- **전용 테인트**: `workload=llm-model:NoSchedule`
- **전용 라벨**: `workload=llm-model`

### 안정성 설정
- **축소 억제**: `consolidation.enabled = false`
- **빈 노드 TTL**: 1시간
- **노드 만료 TTL**: 30일
- **PDB**: 최소 1개 파드 유지

### 보안 설정
- **EBS 암호화**: 활성화
- **루트 볼륨**: gp3 100Gi (IOPS 3000, Throughput 125)
- **IRSA**: Karpenter 컨트롤러용 최소 권한

## 혼용 가드레일

### 중복 관리 금지
- **Karpenter 대상 노드그룹**: Cluster Autoscaler 태그 부착 금지
- **핵심 컨트롤러**: core 노드에 고정 (Karpenter, CA, CoreDNS 등)
- **스팟 중단 핸들러**: 하나만 사용 (현재 구성은 온디맨드)

### 기존 NodeGroup 마이그레이션
1. 워크로드가 Karpenter 노드에서 정상 동작하는지 확인
2. 기존 NodeGroup의 `desired` 및 `min` 값을 0으로 설정
3. 노드 드레인 후 NodeGroup 삭제
4. **중복 관리 금지**: Karpenter 대상 노드그룹에는 CA 태그 부착 금지

## 롤백 방법

### 기존 NodeGroup이 있는 경우
```bash
# 기존 NodeGroup 복구
kubectl patch nodegroup <existing-llm-nodegroup> --type='merge' -p='{"spec":{"desired":2,"min":1}}'

# Karpenter Provisioner 비활성화
kubectl delete provisioner llm-arm-ondemand

# 워크로드 재배포
kubectl rollout restart deployment/llm-model-deployment
```

### 완전 롤백
```bash
# Terraform 리소스 삭제 (역순)
terraform destroy -target=kubernetes_manifest.karpenter_provisioner_llm
terraform destroy -target=kubernetes_manifest.karpenter_awsnodetemplate_llm
terraform destroy -target=helm_release.karpenter
terraform destroy -target=aws_iam_instance_profile.karpenter_node
terraform destroy -target=aws_iam_role.karpenter_node
terraform destroy -target=aws_iam_role.karpenter_controller
```

## 추가 구성

### 스팟 버스트용 별도 Provisioner
필요시 스팟 인스턴스를 사용하는 별도 Provisioner를 추가할 수 있습니다:

```yaml
# provisioner_llm_spot.tf
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: llm-arm-spot
spec:
  requirements:
    nodeSelector:
    - key: karpenter.sh/capacity-type
      operator: In
      values: [spot]
    - key: kubernetes.io/arch
      operator: In
      values: [arm64]
    - key: node.kubernetes.io/instance-type
      operator: In
      values: [t4g.medium, t4g.large]
  # ... 기타 설정
```

## 문제 해결

### 일반적인 문제
1. **노드가 생성되지 않는 경우**: IAM 권한 및 서브넷/보안그룹 태그 확인
2. **파드가 스케줄링되지 않는 경우**: nodeSelector 및 tolerations 확인
3. **이미지 pull 실패**: ARM64 이미지 사용 여부 확인

### 로그 확인
```bash
# Karpenter 컨트롤러 로그
kubectl -n karpenter logs -f deploy/karpenter

# 노드 이벤트
kubectl get events --sort-by=.metadata.creationTimestamp

# 파드 이벤트
kubectl describe pod <pod-name>
```

## 이미지 요구사항

- LLM 컨테이너 이미지는 **ARM64 빌드** 또는 **멀티아키텍처**여야 함
- 예시 이미지: `huggingface/transformers-pytorch-gpu:latest`
- 실제 운영에서는 ARM64 전용 이미지 사용 권장

## 비용 최적화

- **온디맨드 전용**: 안정성 우선, 비용 예측 가능
- **축소 억제**: 워크로드 안정성 우선
- **적절한 리소스 요청**: 오버프로비저닝 방지
- **스팟 인스턴스**: 필요시 별도 Provisioner로 추가 가능
