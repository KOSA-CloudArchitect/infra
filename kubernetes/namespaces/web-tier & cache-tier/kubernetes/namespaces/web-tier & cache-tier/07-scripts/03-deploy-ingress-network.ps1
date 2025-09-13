# EKS Migration - Ingress 및 Network Policy 배포 스크립트 (PowerShell)
# Task 5: Ingress 및 네트워크 설정 배포

param(
    [switch]$SkipALBCheck,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 EKS Ingress 및 Network Policy 배포 시작..." -ForegroundColor Cyan

# 함수 정의
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# 네임스페이스 존재 확인
function Test-Namespace {
    param([string]$Namespace)
    
    try {
        kubectl get namespace $Namespace | Out-Null
        Write-LogSuccess "네임스페이스 '$Namespace' 존재 확인"
        return $true
    }
    catch {
        Write-LogError "네임스페이스 '$Namespace'가 존재하지 않습니다"
        return $false
    }
}

# AWS Load Balancer Controller 설치 확인
function Test-ALBController {
    Write-LogInfo "AWS Load Balancer Controller 설치 상태 확인..."
    
    try {
        $deployment = kubectl get deployment aws-load-balancer-controller -n kube-system -o json | ConvertFrom-Json
        $readyReplicas = $deployment.status.readyReplicas
        $desiredReplicas = $deployment.spec.replicas
        
        if ($readyReplicas -eq $desiredReplicas -and $readyReplicas -gt 0) {
            Write-LogSuccess "AWS Load Balancer Controller가 정상 실행 중입니다 ($readyReplicas/$desiredReplicas)"
            return $true
        }
        else {
            Write-LogWarning "AWS Load Balancer Controller가 완전히 준비되지 않았습니다 ($readyReplicas/$desiredReplicas)"
            return $false
        }
    }
    catch {
        Write-LogError "AWS Load Balancer Controller가 설치되지 않았습니다"
        Write-LogInfo "다음 명령으로 설치하세요:"
        Write-Host "  helm repo add eks https://aws.github.io/eks-charts"
        Write-Host "  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \"
        Write-Host "    -n kube-system \"
        Write-Host "    --set clusterName=hihypipe-cluster \"
        Write-Host "    --set serviceAccount.create=false \"
        Write-Host "    --set serviceAccount.name=aws-load-balancer-controller"
        return $false
    }
}

try {
    # 필수 네임스페이스 확인
    Write-LogInfo "필수 네임스페이스 존재 확인..."
    $requiredNamespaces = @("web-tier", "cache-tier", "monitoring")
    $missingNamespaces = @()

    foreach ($ns in $requiredNamespaces) {
        if (-not (Test-Namespace $ns)) {
            $missingNamespaces += $ns
        }
    }

    if ($missingNamespaces.Count -gt 0) {
        Write-LogError "다음 네임스페이스가 누락되었습니다: $($missingNamespaces -join ', ')"
        Write-LogInfo "먼저 01-namespaces.yaml을 배포하세요:"
        Write-Host "  kubectl apply -f k8s-manifests/01-namespaces.yaml"
        exit 1
    }

    # AWS Load Balancer Controller 확인 (스킵 옵션이 없는 경우)
    if (-not $SkipALBCheck) {
        if (-not (Test-ALBController)) {
            Write-LogError "AWS Load Balancer Controller가 준비되지 않았습니다"
            Write-LogInfo "'-SkipALBCheck' 옵션을 사용하여 이 확인을 건너뛸 수 있습니다"
            exit 1
        }
    }

    if ($DryRun) {
        Write-LogInfo "DRY RUN 모드: 실제 배포는 수행하지 않습니다"
        Write-LogInfo "다음 파일들이 배포될 예정입니다:"
        Write-Host "  - k8s-manifests/07-ingress-resources.yaml"
        Write-Host "  - k8s-manifests/08-network-policies.yaml"
        exit 0
    }

    # Ingress 리소스 배포
    Write-LogInfo "Ingress 리소스 배포 중..."
    kubectl apply -f k8s-manifests/07-ingress-resources.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-LogSuccess "Ingress 리소스 배포 완료"
    }
    else {
        throw "Ingress 리소스 배포 실패"
    }

    # Network Policy 배포
    Write-LogInfo "Network Policy 배포 중..."
    kubectl apply -f k8s-manifests/08-network-policies.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-LogSuccess "Network Policy 배포 완료"
    }
    else {
        throw "Network Policy 배포 실패"
    }

    # 배포 상태 확인
    Write-LogInfo "배포 상태 확인 중..."

    Write-Host ""
    Write-LogInfo "=== Ingress 리소스 상태 ==="
    kubectl get ingress -n web-tier
    kubectl get ingress -n monitoring

    Write-Host ""
    Write-LogInfo "=== Network Policy 상태 ==="
    kubectl get networkpolicy -n web-tier
    kubectl get networkpolicy -n cache-tier
    kubectl get networkpolicy -n monitoring

    Write-Host ""
    Write-LogInfo "=== ALB 생성 상태 확인 ==="
    Write-LogWarning "ALB 생성에는 2-3분이 소요될 수 있습니다..."

    # ALB 생성 대기 (최대 5분)
    $timeout = 300
    $elapsed = 0
    $albCreated = $false

    while ($elapsed -lt $timeout) {
        try {
            $ingress = kubectl get ingress web-tier-ingress -n web-tier -o json | ConvertFrom-Json
            $albAddress = $ingress.status.loadBalancer.ingress[0].hostname
            
            if ($albAddress) {
                Write-LogSuccess "ALB 생성 완료: $albAddress"
                $albCreated = $true
                break
            }
        }
        catch {
            # ALB가 아직 생성되지 않음
        }
        
        Write-Host "." -NoNewline
        Start-Sleep 10
        $elapsed += 10
    }

    if (-not $albCreated) {
        Write-LogWarning "ALB 생성 확인 시간 초과. 수동으로 확인하세요:"
        Write-Host "  kubectl get ingress -n web-tier"
    }

    Write-Host ""
    Write-LogSuccess "🎉 Ingress 및 Network Policy 배포가 완료되었습니다!"

    Write-Host ""
    Write-LogInfo "=== 다음 단계 ==="
    Write-Host "1. ALB DNS 이름 확인:"
    Write-Host "   kubectl get ingress web-tier-ingress -n web-tier"
    Write-Host ""
    Write-Host "2. 서비스 연결 테스트:"
    Write-Host "   curl http://<ALB-DNS-NAME>/health"
    Write-Host ""
    Write-Host "3. SSL 인증서 설정 (프로덕션 환경):"
    Write-Host "   - ACM에서 SSL 인증서 생성"
    Write-Host "   - 07-ingress-resources.yaml에서 certificate-arn 주석 업데이트"
    Write-Host ""
    Write-Host "4. 도메인 설정:"
    Write-Host "   - Route 53에서 도메인을 ALB로 연결"
    Write-Host "   - Ingress 리소스에 host 규칙 추가"

}
catch {
    Write-LogError "배포 중 오류 발생: $($_.Exception.Message)"
    exit 1
}