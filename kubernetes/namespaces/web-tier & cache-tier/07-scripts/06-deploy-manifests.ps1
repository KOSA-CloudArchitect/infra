# EKS Migration - Kubernetes 매니페스트 배포 스크립트 (PowerShell)
# Task 3: Kubernetes 매니페스트 작성 및 배포

param(
    [switch]$DryRun,
    [switch]$SkipSecrets,
    [string]$Namespace = "web-tier"
)

# 색상 함수
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    switch ($Color) {
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Blue" { Write-Host $Message -ForegroundColor Blue }
        "Cyan" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

function Log-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Blue"
}

function Log-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" "Green"
}

function Log-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

function Log-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

# 스크립트 시작
Log-Info "EKS Migration - Kubernetes 매니페스트 배포 시작"

# kubectl 설치 확인
try {
    $null = Get-Command kubectl -ErrorAction Stop
    Log-Success "kubectl 명령어 확인됨"
} catch {
    Log-Error "kubectl이 설치되지 않았거나 PATH에 없습니다."
    exit 1
}

# kubectl 연결 확인
Log-Info "kubectl 연결 상태 확인 중..."
try {
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "클러스터 연결 실패"
    }
    
    $currentContext = kubectl config current-context
    Log-Success "클러스터 연결 확인: $currentContext"
} catch {
    Log-Error "kubectl이 클러스터에 연결되지 않았습니다. EKS 클러스터 연결을 확인하세요."
    Log-Error "다음 명령어로 클러스터에 연결하세요:"
    Log-Error "aws eks update-kubeconfig --region ap-northeast-2 --name your-cluster-name"
    exit 1
}

# Dry Run 모드 확인
if ($DryRun) {
    Log-Warning "Dry Run 모드로 실행됩니다. 실제 리소스는 생성되지 않습니다."
    $dryRunFlag = "--dry-run=client"
} else {
    $dryRunFlag = ""
}

try {
    # 1단계: 네임스페이스 생성
    Log-Info "1단계: 네임스페이스 및 기본 리소스 생성 중..."
    
    if ($DryRun) {
        kubectl apply -f "01-namespaces.yaml" --dry-run=client
    } else {
        kubectl apply -f "01-namespaces.yaml"
    }
    
    if ($LASTEXITCODE -eq 0) {
        Log-Success "네임스페이스 생성 완료"
    } else {
        throw "네임스페이스 생성 실패"
    }

    # 네임스페이스 생성 대기 (Dry Run이 아닌 경우)
    if (-not $DryRun) {
        Log-Info "네임스페이스 생성 대기 중..."
        Start-Sleep -Seconds 5
    }

    # 2단계: ConfigMap 및 Secret 생성
    if (-not $SkipSecrets) {
        Log-Info "2단계: ConfigMap 및 Secret 리소스 생성 중..."
        Log-Warning "주의: Secret 값들을 실제 환경에 맞게 수정해야 합니다!"

        if ($DryRun) {
            kubectl apply -f "03-configmaps-secrets.yaml" --dry-run=client
        } else {
            kubectl apply -f "03-configmaps-secrets.yaml"
        }

        if ($LASTEXITCODE -eq 0) {
            Log-Success "ConfigMap 및 Secret 생성 완료"
        } else {
            throw "ConfigMap 및 Secret 생성 실패"
        }
    } else {
        Log-Warning "Secret 생성을 건너뜁니다."
    }

    # 3단계: Frontend 배포
    Log-Info "3단계: Frontend (Next.js) 배포 중..."
    
    if ($DryRun) {
        kubectl apply -f "04-frontend-deployment.yaml" --dry-run=client
    } else {
        kubectl apply -f "04-frontend-deployment.yaml"
    }

    if ($LASTEXITCODE -eq 0) {
        Log-Success "Frontend 배포 완료"
    } else {
        throw "Frontend 배포 실패"
    }

    # 4단계: Backend 배포
    Log-Info "4단계: Backend 배포 중..."
    
    if ($DryRun) {
        kubectl apply -f "05-backend-deployment.yaml" --dry-run=client
    } else {
        kubectl apply -f "05-backend-deployment.yaml"
    }

    if ($LASTEXITCODE -eq 0) {
        Log-Success "Backend 배포 완료"
    } else {
        throw "Backend 배포 실패"
    }

    # 5단계: WebSocket 배포
    Log-Info "5단계: WebSocket 서버 배포 중..."
    
    if ($DryRun) {
        kubectl apply -f "06-websocket-deployment.yaml" --dry-run=client
    } else {
        kubectl apply -f "06-websocket-deployment.yaml"
    }

    if ($LASTEXITCODE -eq 0) {
        Log-Success "WebSocket 서버 배포 완료"
    } else {
        throw "WebSocket 서버 배포 실패"
    }

    # Dry Run이 아닌 경우에만 상태 확인
    if (-not $DryRun) {
        # 배포 상태 확인
        Log-Info "배포 상태 확인 중..."
        Write-Host ""
        
        Log-Info "네임스페이스 목록:"
        kubectl get namespaces -l app.kubernetes.io/part-of=review-analysis-system

        Write-Host ""
        Log-Info "web-tier 네임스페이스의 리소스:"
        kubectl get all -n web-tier

        Write-Host ""
        Log-Info "cache-tier 네임스페이스의 리소스:"
        kubectl get all -n cache-tier

        Write-Host ""
        Log-Info "ConfigMap 및 Secret 확인:"
        kubectl get configmaps,secrets -n web-tier
        kubectl get configmaps,secrets -n cache-tier

        # Pod 상태 확인
        Log-Info "Pod 상태 확인 중..."
        Write-Host ""
        Log-Info "web-tier Pod 상태:"
        kubectl get pods -n web-tier -o wide

        # HPA 상태 확인
        Write-Host ""
        Log-Info "HPA 상태 확인:"
        kubectl get hpa -n web-tier

        # 서비스 상태 확인
        Write-Host ""
        Log-Info "서비스 상태 확인:"
        kubectl get services -n web-tier
    }

    Write-Host ""
    Log-Success "Kubernetes 매니페스트 배포가 완료되었습니다!"

    # 다음 단계 안내
    Write-Host ""
    Log-Info "다음 단계:"
    Log-Info "1. ECR에 컨테이너 이미지를 푸시하세요"
    Log-Info "2. Secret 값들을 실제 환경에 맞게 업데이트하세요"
    Log-Info "3. Redis 클러스터를 배포하세요"
    Log-Info "4. Ingress 리소스를 생성하세요"
    Log-Info "5. 모니터링 및 로깅을 설정하세요"

    Write-Host ""
    Log-Info "유용한 명령어:"
    Log-Info "- Pod 로그 확인: kubectl logs -f deployment/frontend-deployment -n web-tier"
    Log-Info "- Pod 상태 모니터링: kubectl get pods -n web-tier -w"
    Log-Info "- 서비스 포트 포워딩: kubectl port-forward service/frontend-service 3000:3000 -n web-tier"
    Log-Info "- 리소스 삭제: kubectl delete -f ."

} catch {
    Log-Error "배포 중 오류 발생: $_"
    exit 1
}

Write-Host ""
Log-Success "배포 스크립트 실행 완료!"

# 사용법 안내
Write-Host ""
Log-Info "스크립트 사용법:"
Log-Info "  .\deploy-manifests.ps1                    # 전체 배포"
Log-Info "  .\deploy-manifests.ps1 -DryRun           # Dry Run 모드"
Log-Info "  .\deploy-manifests.ps1 -SkipSecrets      # Secret 생성 건너뛰기"