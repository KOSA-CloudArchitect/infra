pipeline {
    // 검증에 필요한 도구(kubectl, helm)가 포함된 Agent Pod를 정의
    agent {
        kubernetes {
            label 'validator-agent'
            yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: default
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
  # kubectl 명령어를 위한 컨테이너
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["sleep"], args: ["infinity"]
  # helm 명령어를 위한 컨테이너
  - name: helm
    image: alpine/helm:latest
    command: ["sleep"], args: ["infinity"]
"""
        }
    }

    stages {
        stage('Checkout Manifests') {
            steps {
                // 파이프라인 SCM 설정에 따라 infra 리포지토리 코드를 체크아웃
                checkout scm
            }
        }

        stage('Validate Kubernetes YAMLs') {
            steps {
                // kubectl 컨테이너 안에서 실행
                container('kubectl') {
                    script {
                        echo "--- Validating Kubernetes namespaces YAMLs ---"
                        // kubernetes/namespaces 폴더 내의 모든 .yaml 파일 검증
                        // kustomization.yaml을 제외하고 순수 YAML 파일만 검증
                        sh 'find kubernetes/namespaces -type f -name "*.yaml" ! -name "kustomization.yaml" -exec kubectl apply --dry-run=client -f {} \\;'
                    }
                }
            }
        }

        stage('Validate Helm Charts') {
            steps {
                // helm 컨테이너 안에서 실행
                container('helm') {
                    script {
                        echo "--- Linting Airflow Helm chart ---"
                        // Airflow 차트에 대해 문법 및 권장사항 검증
                        sh 'helm lint kubernetes/helm-chart/airflow'

                        echo "--- Validating rendered Airflow Helm template ---"
                        // Airflow 차트를 실제 Kubernetes YAML로 변환한 뒤, 그 결과물을 kubectl로 다시 검증
                        sh 'helm template airflow-release kubernetes/helm-chart/airflow | kubectl apply --dry-run=client -f -'
                    }
                }
            }
        }
    }

    post {
        // 파이프라인의 성공/실패 여부에 따라 최종 상태를 출력
        always {
            echo 'Validation pipeline finished.'
        }
        success {
            echo 'All manifests are valid!'
        }
        failure {
            echo 'Validation failed. Please check the logs.'
        }
    }
}
