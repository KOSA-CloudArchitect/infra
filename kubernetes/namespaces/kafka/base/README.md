# Kafka 클러스터 배포 가이드

이 디렉토리는 AWS EKS에서 Strimzi Kafka 클러스터를 배포하기 위한 모든 필요한 파일들을 포함합니다.

## 📁 파일 구조

```
kafka/
├── deploy-kafka.sh              # 통합 배포 스크립트 (EBS CSI, Helm, 상태 점검 포함)
├── cleanup-kafka.sh             # 정리 스크립트
├── storageclass.yaml            # StorageClass 설정 (gp3-wait)
├── kafka_crd.yaml               # Kafka 클러스터 및 NodePools 정의
├── kafka-topic.yaml             # Kafka Topics 정의
├── kafka_bridge.yaml            # Kafka Bridge 설정
├── kafka-connect-prebuilt.yaml  # Kafka Connect 리소스 정의
├── kafka-s3-sink-connector.yaml # S3 Sink Connector 예시
├── kafka-jdbc-sink-connector.yaml
├── kafka-mongo-sink-connector.yaml
└── README.md
```

## 🚀 배포 방법

### 1. 자동 배포 (권장)

```bash
# 실행 권한 부여
chmod +x deploy-kafka.sh

# Kafka 클러스터 배포
./deploy-kafka.sh
```

배포 스크립트는 다음을 자동 점검/수행합니다.
- kubectl/Helm 설치 확인 (Helm 미설치 시 설치 가이드 출력)
- EBS CSI Driver 존재 확인(미설치 시 EKS Add-on/Helm 설치 안내)
- 네임스페이스 생성 및 라벨 부여 (ResourceQuota/LimitRange는 기본 미적용)
- Strimzi Operator 설치/업그레이드 (nodeSelector만 적용, toleration 미사용)
- StorageClass 적용 및 기본 클래스 상태 점검
- Kafka, Topics, Bridge, Connect 배포
- Kafka Connect 배포 후 Pod Identity/IRSA 연결 점검(안내 포함)
- Connector 정리 후 재배포 및 상태 확인

### 2. 수동 배포

```bash
# 1. 네임스페이스 생성 (Quota/Limit 미적용)
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace kafka name=kafka purpose=kafka-cluster --overwrite
kubectl delete resourcequota --all -n kafka --ignore-not-found=true
kubectl delete limitrange --all -n kafka --ignore-not-found=true

# 2. StorageClass 설정
kubectl apply -f storageclass.yaml

# 3. Kafka 클러스터 배포
kubectl apply -f kafka_crd.yaml

# 4. Kafka Topics 배포
kubectl apply -f kafka-topic.yaml

# 5. Kafka Bridge 배포
kubectl apply -f kafka_bridge.yaml
```

## 🗑️ 정리 방법

### 자동 정리

```bash
# 실행 권한 부여
chmod +x cleanup-kafka.sh

# Kafka 클러스터 정리
./cleanup-kafka.sh
```

### 수동 정리

```bash
# 1. Kafka 리소스 삭제
kubectl delete -f kafka_bridge.yaml --ignore-not-found=true
kubectl delete -f kafka-topic.yaml --ignore-not-found=true
kubectl delete kafka my-cluster -n kafka --ignore-not-found=true
kubectl delete kafkanodepool --all -n kafka --ignore-not-found=true

# 2. 스토리지 정리
kubectl delete pvc --all -n kafka --ignore-not-found=true

# 3. 네임스페이스 삭제
kubectl delete namespace kafka --ignore-not-found=true

# 4. StorageClass 정리
kubectl delete storageclass gp3-wait --ignore-not-found=true
```

## 📊 배포 확인

```bash
# Pod 상태 확인
kubectl get pods -n kafka

# Kafka 클러스터 상태 확인
kubectl get kafka -n kafka

# NodePools 상태 확인
kubectl get kafkanodepool -n kafka

# PVC 상태 확인
kubectl get pvc -n kafka

# StorageClass 확인
kubectl get storageclass
```

## 🔧 주요 설정

### StorageClass 설정
- **gp3-wait**: WaitForFirstConsumer 모드로 Pod 스케줄링 시점에 EBS 볼륨 생성
- **gp3 타입**: 최신 EBS 볼륨 타입, 성능 최적화
- **IOPS**: 3000, **Throughput**: 125 MiB/s

### 노드 스케줄링
- **대상 노드 그룹**: `kafka-storage-on-20250908020539785800000018`
- **Node Selector**만 사용 (toleration 비사용)

### 네임스페이스 리소스 할당량
- 기본값: ResourceQuota/LimitRange 미적용 (Pod 스펙의 requests/limits만 사용)
- 필요 시 별도 `resource/` 디렉토리의 예시 YAML을 참고하여 수동 적용

### EBS CSI / Pod Identity (중요)
- 권장: EKS Managed Add-on으로 `aws-ebs-csi-driver` 설치 및 관리
- Kafka Connect용 ServiceAccount: 기본적으로 `my-connect-connect` (`kafka` ns)
- Pod Identity 사용 시 ServiceAccount에는 IRSA annotation이 생성되지 않습니다.

확인 명령어:
```bash
# EBS CSI Driver 설치 여부
kubectl get csidriver ebs.csi.aws.com

# Pod Identity 연결 상태 (Kafka Connect)
aws eks list-pod-identity-associations --cluster-name <CLUSTER_NAME> \
  --query 'associations[?namespace==`kafka` && serviceAccount==`my-connect-connect`]'

# IRSA 여부 확인 (IRSA를 사용하는 경우에만 주석 존재)
kubectl get sa my-connect-connect -n kafka -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'; echo
```

## 🌐 접근 방법

### Kafka Bridge 접근
```bash
# 포트 포워딩
kubectl port-forward -n kafka service/my-cluster-kafka-bridge 8080:8080

# 브라우저에서 접근
http://localhost:8080
```

### Kafka 클러스터 내부 접근
```bash
# Kafka Pod에 접근
kubectl exec -it my-cluster-broker-0 -n kafka -- /bin/bash

# Kafka 명령어 실행
kubectl exec -it my-cluster-broker-0 -n kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## 🔍 문제 해결

### Pod가 Pending 상태인 경우
```bash
# Pod 상세 정보 확인
kubectl describe pod <pod-name> -n kafka

# 일반적인 원인:
# 1. 노드 affinity 문제
# 2. PVC 바인딩 문제
# 3. 리소스 부족
```

### PVC가 Pending 상태인 경우
```bash
# PVC 상세 정보 확인
kubectl describe pvc <pvc-name> -n kafka

# 일반적인 원인:
# 1. StorageClass 문제
# 2. 노드 affinity 문제
# 3. EBS 볼륨 생성 실패
```

### 로그 확인
```bash
# Strimzi Operator 로그
kubectl logs -n kafka deployment/strimzi-cluster-operator

# Kafka Pod 로그
kubectl logs -n kafka my-cluster-broker-0
kubectl logs -n kafka my-cluster-controller-1
```

## 📝 유용한 명령어

```bash
# 실시간 Pod 상태 모니터링
kubectl get pods -n kafka -w

# 리소스 사용량 확인
kubectl top pods -n kafka
kubectl top nodes

# 이벤트 확인
kubectl get events -n kafka --sort-by='.lastTimestamp'

# 네임스페이스 리소스 확인
kubectl get all -n kafka

# Kafka Connect 및 Connector 운용
kubectl get kafkaconnect -n kafka
kubectl get kafkaconnector -n kafka
kubectl describe kafkaconnector <connector-name> -n kafka

# Connector 재배포/삭제 예시
kubectl delete kafkaconnector --all -n kafka
kubectl apply -f kafka-s3-sink-connector.yaml
```

## ⚠️ 주의사항

1. **데이터 손실**: 정리 스크립트 실행 시 모든 Kafka 데이터가 삭제됩니다.
2. **노드 그룹 이름**: 실제 환경에서는 노드 그룹 이름을 확인하고 수정해야 합니다.
3. **리소스 할당량**: 기본 미적용. 프로덕션 환경에서는 필요 시 별도 적용을 고려하세요.
4. **보안**: 프로덕션 환경에서는 TLS 설정과 인증을 추가해야 합니다.
