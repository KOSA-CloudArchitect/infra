# strimzi-kafka-operator 설치
helm repo add strimzi https://strimzi.io/charts/

helm repo update

helm install strimzi-operator strimzi/strimzi-kafka-operator --version 0.47.0 --namespace kafka --create-namespace

# kafka 설치
kubectl apply -f kafka_crd.yaml

# kafka 모니터링 설치
#helm install kafka-monitoring strimzi/strimzi-kafka-monitoring --version 0.47.0 --namespace kafka --create-namespace