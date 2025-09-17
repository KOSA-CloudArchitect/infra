#!/bin/bash

# Karpenter 노드 클러스터 조인 실패 및 과다 인스턴스 생성 문제 해결 스크립트

echo "🚀 Karpenter 설정 수정 적용 시작..."

# 1. Terraform 포맷팅 및 검증
echo "📝 Terraform 포맷팅 및 검증..."
terraform fmt
terraform validate

if [ $? -ne 0 ]; then
    echo "❌ Terraform 검증 실패. 설정을 확인하세요."
    exit 1
fi

# 2. Terraform 계획 확인
echo "📋 Terraform 계획 확인..."
terraform plan

echo "⚠️  위의 계획을 확인하고 계속하려면 Enter를 누르세요..."
read

# 3. Terraform 적용
echo "🔧 Terraform 적용 중..."
terraform apply -auto-approve

if [ $? -ne 0 ]; then
    echo "❌ Terraform 적용 실패."
    exit 1
fi

echo "✅ Terraform 적용 완료!"

# 4. Karpenter 컨트롤러 재시작
echo "🔄 Karpenter 컨트롤러 재시작 중..."
kubectl rollout restart deployment/karpenter -n karpenter

echo "⏳ Karpenter 컨트롤러 재시작 완료까지 대기 중..."
kubectl rollout status deployment/karpenter -n karpenter

echo "✅ Karpenter 컨트롤러 재시작 완료!"

# 5. 다음 단계 안내
echo ""
echo "🎯 다음 단계를 수행하세요:"
echo "1. aws-auth ConfigMap 수정 (aws-auth-configmap-fix.md 참조)"
echo "2. 모니터링 명령어 실행:"
echo "   kubectl logs -n karpenter deployment/karpenter -f | grep -i 'node\|join\|bootstrap\|error'"
echo "   watch kubectl get nodes -l workload=core"
echo ""
echo "📖 자세한 가이드는 aws-auth-configmap-fix.md 파일을 참조하세요."



