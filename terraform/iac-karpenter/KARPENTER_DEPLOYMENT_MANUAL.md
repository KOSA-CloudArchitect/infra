# 🚀 Karpenter 워크로드 배포 메뉴얼

## 📋 개요
이 메뉴얼은 Karpenter가 설정된 EKS 클러스터에서 각 워크로드별로 파드를 배포하는 방법을 설명합니다.

## 🏗️ 현재 Karpenter NodePool 구성

| 워크로드 | NodePool | 테인트 | 자동삭제 | 만료시간 |
|---------|----------|--------|----------|----------|
| **Core** | `core-arm-ondemand` | ❌ 없음 | 수동 | 30분 |
| **Kafka** | `kafka-arm-ondemand` | `workload=kafka:NoSchedule` | ✅ 자동 | 24시간 |
| **Spark Exec** | `spark-exec-arm-ondemand` | `workload=spark-exec:NoSchedule` | ✅ 자동 | 2시간 |
| **Airflow** | `airflow-arm-ondemand` | `workload=airflow:NoSchedule` | ✅ 자동 | 12시간 |
| **LLM** | `llm-arm-ondemand` | `workload=llm-model:NoSchedule` | ✅ 자동 | 30일 |

---

## 🔧 1. Jenkins Agent 배포

### 1.1 Jenkins Agent Pod (Core 노드 사용)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: jenkins-agent-pod
  labels:
    app: jenkins-agent
spec:
  nodeSelector:
    workload: core  # Core 노드 사용 (테인트 없음)
  containers:
  - name: python
    image: python:3.9-bullseye
    command: ["sleep"]
    args: ["infinity"]
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1"
  - name: podman
    image: quay.io/podman/stable
    command: ["sleep"]
    args: ["infinity"]
    securityContext:
      privileged: true
    resources:
      requests:
        memory: "512Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["sleep"]
    args: ["infinity"]
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "200m"
```

### 1.2 Jenkins Agent Deployment (권장)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-agent-deployment
  labels:
    app: jenkins-agent
spec:
  replicas: 2
  selector:
    matchLabels:
      app: jenkins-agent
  template:
    metadata:
      labels:
        app: jenkins-agent
    spec:
      nodeSelector:
        workload: core
      containers:
      - name: python
        image: python:3.9-bullseye
        command: ["sleep"]
        args: ["infinity"]
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
      - name: podman
        image: quay.io/podman/stable
        command: ["sleep"]
        args: ["infinity"]
        securityContext:
          privileged: true
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      - name: aws-cli
        image: amazon/aws-cli:latest
        command: ["sleep"]
        args: ["infinity"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
```

---

## ☕ 2. Kafka 워크로드 배포

### 2.1 Kafka Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kafka-pod
  labels:
    app: kafka
spec:
  nodeSelector:
    workload: kafka
  tolerations:
  - key: workload
    value: kafka
    effect: NoSchedule
  containers:
  - name: kafka
    image: confluentinc/cp-kafka:latest
    env:
    - name: KAFKA_ZOOKEEPER_CONNECT
      value: "zookeeper:2181"
    - name: KAFKA_ADVERTISED_LISTENERS
      value: "PLAINTEXT://kafka:9092"
    - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
      value: "1"
    resources:
      requests:
        memory: "2Gi"
        cpu: "1"
      limits:
        memory: "4Gi"
        cpu: "2"
    ports:
    - containerPort: 9092
```

### 2.2 Kafka Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-deployment
  labels:
    app: kafka
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      nodeSelector:
        workload: kafka
      tolerations:
      - key: workload
        value: kafka
        effect: NoSchedule
      containers:
      - name: kafka
        image: confluentinc/cp-kafka:latest
        env:
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "zookeeper:2181"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka:9092"
        - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
          value: "1"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        ports:
        - containerPort: 9092
```

---

## ⚡ 3. Spark Executor 워크로드 배포

### 3.1 Spark Executor Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spark-executor-pod
  labels:
    app: spark-executor
spec:
  nodeSelector:
    workload: spark-exec
  tolerations:
  - key: workload
    value: spark-exec
    effect: NoSchedule
  containers:
  - name: spark-executor
    image: apache/spark:3.5.0-scala2.12-java11-python3-ubuntu
    command: ["spark-class"]
    args: ["org.apache.spark.executor.CoarseGrainedExecutorBackend"]
    env:
    - name: SPARK_MASTER_URL
      value: "spark://spark-master:7077"
    resources:
      requests:
        memory: "2Gi"
        cpu: "1"
      limits:
        memory: "4Gi"
        cpu: "2"
```

### 3.2 Spark Executor Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-executor-deployment
  labels:
    app: spark-executor
spec:
  replicas: 5
  selector:
    matchLabels:
      app: spark-executor
  template:
    metadata:
      labels:
        app: spark-executor
    spec:
      nodeSelector:
        workload: spark-exec
      tolerations:
      - key: workload
        value: spark-exec
        effect: NoSchedule
      containers:
      - name: spark-executor
        image: apache/spark:3.5.0-scala2.12-java11-python3-ubuntu
        command: ["spark-class"]
        args: ["org.apache.spark.executor.CoarseGrainedExecutorBackend"]
        env:
        - name: SPARK_MASTER_URL
          value: "spark://spark-master:7077"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
```

---

## 🌪️ 4. Airflow 워크로드 배포

### 4.1 Airflow Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: airflow-pod
  labels:
    app: airflow
spec:
  nodeSelector:
    workload: airflow
  tolerations:
  - key: workload
    value: airflow
    effect: NoSchedule
  containers:
  - name: airflow
    image: apache/airflow:2.7.0-python3.10
    env:
    - name: AIRFLOW__CORE__EXECUTOR
      value: "LocalExecutor"
    - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
      value: "postgresql://airflow:airflow@postgres:5432/airflow"
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1"
    ports:
    - containerPort: 8080
```

### 4.2 Airflow Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-deployment
  labels:
    app: airflow
spec:
  replicas: 2
  selector:
    matchLabels:
      app: airflow
  template:
    metadata:
      labels:
        app: airflow
    spec:
      nodeSelector:
        workload: airflow
      tolerations:
      - key: workload
        value: airflow
        effect: NoSchedule
      containers:
      - name: airflow
        image: apache/airflow:2.7.0-python3.10
        env:
        - name: AIRFLOW__CORE__EXECUTOR
          value: "LocalExecutor"
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql://airflow:airflow@postgres:5432/airflow"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
        ports:
        - containerPort: 8080
```

---

## 🤖 5. LLM 워크로드 배포

### 5.1 LLM Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: llm-pod
  labels:
    app: llm
spec:
  nodeSelector:
    workload: llm-model
  tolerations:
  - key: workload
    value: llm-model
    effect: NoSchedule
  containers:
  - name: llm
    image: huggingface/transformers-pytorch-gpu:latest
    env:
    - name: MODEL_NAME
      value: "microsoft/DialoGPT-medium"
    resources:
      requests:
        memory: "4Gi"
        cpu: "2"
        nvidia.com/gpu: 1
      limits:
        memory: "8Gi"
        cpu: "4"
        nvidia.com/gpu: 1
```

### 5.2 LLM Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-deployment
  labels:
    app: llm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llm
  template:
    metadata:
      labels:
        app: llm
    spec:
      nodeSelector:
        workload: llm-model
      tolerations:
      - key: workload
        value: llm-model
        effect: NoSchedule
      containers:
      - name: llm
        image: huggingface/transformers-pytorch-gpu:latest
        env:
        - name: MODEL_NAME
          value: "microsoft/DialoGPT-medium"
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
            nvidia.com/gpu: 1
          limits:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: 1
```

---

## 🚀 6. 배포 명령어

### 6.1 개별 워크로드 배포
```bash
# Jenkins Agent
kubectl apply -f jenkins-agent-deployment.yaml

# Kafka
kubectl apply -f kafka-deployment.yaml

# Spark Executor
kubectl apply -f spark-executor-deployment.yaml

# Airflow
kubectl apply -f airflow-deployment.yaml

# LLM
kubectl apply -f llm-deployment.yaml
```

### 6.2 모든 워크로드 한번에 배포
```bash
kubectl apply -f jenkins-agent-deployment.yaml
kubectl apply -f kafka-deployment.yaml
kubectl apply -f spark-executor-deployment.yaml
kubectl apply -f airflow-deployment.yaml
kubectl apply -f llm-deployment.yaml
```

---

## 📊 7. 배포 후 확인

### 7.1 파드 상태 확인
```bash
# 모든 파드 상태 확인
kubectl get pods -o wide

# 워크로드별 파드 확인
kubectl get pods -l app=jenkins-agent
kubectl get pods -l app=kafka
kubectl get pods -l app=spark-executor
kubectl get pods -l app=airflow
kubectl get pods -l app=llm
```

### 7.2 노드 상태 확인
```bash
# 모든 노드 상태 확인
kubectl get nodes -o wide

# 워크로드별 노드 확인
kubectl get nodes -l workload=core
kubectl get nodes -l workload=kafka
kubectl get nodes -l workload=spark-exec
kubectl get nodes -l workload=airflow
kubectl get nodes -l workload=llm-model
```

### 7.3 Karpenter 로그 확인
```bash
# Karpenter 로그 실시간 모니터링
kubectl logs -n karpenter deployment/karpenter -f

# Karpenter 로그에서 특정 이벤트 확인
kubectl logs -n karpenter deployment/karpenter | grep -i "nodeclaim\|provision\|consolidat"
```

---

## 🔧 8. 문제 해결

### 8.1 파드가 Pending 상태인 경우
```bash
# 파드 이벤트 확인
kubectl describe pod <pod-name>

# 노드 리소스 확인
kubectl top nodes

# Karpenter 로그 확인
kubectl logs -n karpenter deployment/karpenter --tail=20
```

### 8.2 노드가 생성되지 않는 경우
```bash
# NodePool 상태 확인
kubectl get nodepools

# EC2NodeClass 상태 확인
kubectl get ec2nodeclasses

# 서브넷 태그 확인
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=hihypipe-eks-cluster"
```

### 8.3 리소스 부족 오류
```bash
# 노드 리소스 사용량 확인
kubectl top nodes

# 파드 리소스 요청량 확인
kubectl describe pod <pod-name> | grep -A 10 "Requests:"
```

---

## 📝 9. 주의사항

### 9.1 리소스 요청량 설정
- **requests**: 최소 보장 리소스 (Karpenter가 노드 생성 시 고려)
- **limits**: 최대 사용 리소스 (컨테이너가 초과할 수 없음)

### 9.2 테인트와 톨러레이션
- **Core 노드**: 테인트 없음 → 톨러레이션 불필요
- **전용 노드**: 테인트 있음 → 톨러레이션 필수

### 9.3 자동 스케일링
- **파드 생성**: Karpenter가 자동으로 노드 생성
- **파드 삭제**: 설정된 시간 후 자동으로 노드 삭제

---

## 🎯 10. 성공 지표

### 10.1 정상 배포 확인
- ✅ 모든 파드가 Running 상태
- ✅ 파드가 올바른 노드에 스케줄링됨
- ✅ Karpenter 로그에 오류 없음

### 10.2 자동 스케일링 확인
- ✅ 파드 생성 시 새 노드 자동 생성
- ✅ 파드 삭제 시 노드 자동 삭제 (설정된 시간 후)
- ✅ 리소스 사용량에 따른 적절한 인스턴스 타입 선택

---

이 메뉴얼을 따라하면 Karpenter가 설정된 EKS 클러스터에서 각 워크로드를 효율적으로 배포할 수 있습니다! 🚀



