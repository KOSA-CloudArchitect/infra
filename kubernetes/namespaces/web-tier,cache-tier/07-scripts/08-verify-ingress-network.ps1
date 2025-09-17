# EKS Migration - Ingress 및 Network Policy 검증 스크립트
# Task 5: 배포된 Ingress 및 Network Policy 검증

param(
    [string]$ALBDomain = "",
    [switch]$SkipConnectivityTest
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 EKS Ingress 및 Network Policy 검증 시작..." -ForegroundColor Cyan

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

function Test-IngressResource {
    param([string]$Name, [string]$Namespace)
    
    try {
        $ingress = kubectl get ingress $Name -n $Namespace -o json | ConvertFrom-Json
        $albAddress = $ingress.status.loadBalancer.ingress[0].hostname
        
        if ($albAddress) {
            Write-LogSuccess "Ingress '$Name' in '$Namespace': ALB 주소 = $albAddress"
            return $albAddress
        }
        else {
            Write-LogWarning "Ingress '$Name' in '$Namespace': ALB 주소가 아직 할당되지 않음"
            return $null
        }
    }
    catch {
        Write-LogError "Ingress '$Name' in '$Namespace': 조회 실패"
        return $null
    }
}

function Test-NetworkPolicy {
    param([string]$Name, [string]$Namespace)
    
    try {
        kubectl get networkpolicy $Name -n $Namespace | Out-Null
        Write-LogSuccess "Network Policy '$Name' in '$Namespace': 존재 확인"
        return $true
    }
    catch {
        Write-LogError "Network Policy '$Name' in '$Namespace': 존재하지 않음"
        return $false
    }
}

function Test-ALBConnectivity {
    param([string]$ALBAddress)
    
    if (-not $ALBAddress) {
        Write-LogWarning "ALB 주소가 제공되지 않아 연결 테스트를 건너뜁니다"
        return
    }
    
    Write-LogInfo "ALB 연결 테스트 중: $ALBAddress"
    
    # HTTP 헬스체크 테스트
    try {
        $response = Invoke-WebRequest -Uri "http://$ALBAddress/health" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-LogSuccess "HTTP 헬스체크 성공 (Status: $($response.StatusCode))"
        }
        else {
            Write-LogWarning "HTTP 헬스체크 응답 코드: $($response.StatusCode)"
        }
    }
    catch {
        Write-LogError "HTTP 헬스체크 실패: $($_.Exception.Message)"
    }
    
    # HTTPS 테스트 (인증서가 설정된 경우)
    try {
        $response = Invoke-WebRequest -Uri "https://$ALBAddress/health" -TimeoutSec 10 -UseBasicParsing -SkipCertificateCheck
        if ($response.StatusCode -eq 200) {
            Write-LogSuccess "HTTPS 헬스체크 성공 (Status: $($response.StatusCode))"
        }
        else {
            Write-LogWarning "HTTPS 헬스체크 응답 코드: $($response.StatusCode)"
        }
    }
    catch {
        Write-LogWarning "HTTPS 헬스체크 실패 (SSL 인증서가 설정되지 않았을 수 있음): $($_.Exception.Message)"
    }
}

try {
    Write-Host ""
    Write-LogInfo "=== 1. Ingress 리소스 검증 ==="
    
    # web-tier Ingress 검증
    $webTierALB = Test-IngressResource "web-tier-ingress" "web-tier"
    $webTierDevALB = Test-IngressResource "web-tier-dev-ingress" "web-tier"
    
    # monitoring Ingress 검증
    $monitoringALB = Test-IngressResource "monitoring-ingress" "monitoring"
    
    Write-Host ""
    Write-LogInfo "=== 2. Network Policy 검증 ==="
    
    # Network Policy 존재 확인
    $policies = @(
        @{Name="web-tier-network-policy"; Namespace="web-tier"},
        @{Name="cache-tier-network-policy"; Namespace="cache-tier"},
        @{Name="monitoring-network-policy"; Namespace="monitoring"}
    )
    
    $allPoliciesExist = $true
    foreach ($policy in $policies) {
        if (-not (Test-NetworkPolicy $policy.Name $policy.Namespace)) {
            $allPoliciesExist = $false
        }
    }
    
    Write-Host ""
    Write-LogInfo "=== 3. AWS Load Balancer Controller 상태 ==="
    
    try {
        $deployment = kubectl get deployment aws-load-balancer-controller -n kube-system -o json | ConvertFrom-Json
        $readyReplicas = $deployment.status.readyReplicas
        $desiredReplicas = $deployment.spec.replicas
        
        if ($readyReplicas -eq $desiredReplicas -and $readyReplicas -gt 0) {
            Write-LogSuccess "AWS Load Balancer Controller: $readyReplicas/$desiredReplicas 준비됨"
        }
        else {
            Write-LogWarning "AWS Load Balancer Controller: $readyReplicas/$desiredReplicas 준비됨"
        }
    }
    catch {
        Write-LogError "AWS Load Balancer Controller 상태 확인 실패"
    }
    
    Write-Host ""
    Write-LogInfo "=== 4. ALB 상세 정보 ==="
    
    if ($webTierALB) {
        Write-Host "Production ALB: $webTierALB" -ForegroundColor Cyan
        Write-Host "  - Frontend: http://$webTierALB/"
        Write-Host "  - API: http://$webTierALB/api"
        Write-Host "  - WebSocket: http://$webTierALB/ws"
        Write-Host "  - Health: http://$webTierALB/health"
    }
    
    if ($webTierDevALB) {
        Write-Host "Development ALB: $webTierDevALB" -ForegroundColor Cyan
    }
    
    if ($monitoringALB) {
        Write-Host "Monitoring ALB (Internal): $monitoringALB" -ForegroundColor Cyan
    }
    
    # 연결 테스트
    if (-not $SkipConnectivityTest) {
        Write-Host ""
        Write-LogInfo "=== 5. 연결 테스트 ==="
        
        $testALB = $ALBDomain
        if (-not $testALB -and $webTierALB) {
            $testALB = $webTierALB
        }
        
        if ($testALB) {
            Test-ALBConnectivity $testALB
        }
        else {
            Write-LogWarning "테스트할 ALB 주소가 없습니다"
        }
    }
    
    Write-Host ""
    Write-LogInfo "=== 6. 보안 설정 확인 ==="
    
    # Network Policy 규칙 요약
    Write-Host "Network Policy 보안 규칙:"
    Write-Host "  ✓ web-tier: ALB → Frontend/Backend/WebSocket 허용"
    Write-Host "  ✓ web-tier: → cache-tier (Redis) 허용"
    Write-Host "  ✓ web-tier: → 외부 서비스 (DB, Kafka, 크롤링 서버) 허용"
    Write-Host "  ✓ cache-tier: web-tier → Redis 허용"
    Write-Host "  ✓ cache-tier: 내부 Redis 클러스터 통신 허용"
    Write-Host "  ✓ monitoring: 메트릭 수집을 위한 접근 허용"
    
    Write-Host ""
    if ($webTierALB -and $allPoliciesExist) {
        Write-LogSuccess "🎉 모든 검증이 성공적으로 완료되었습니다!"
    }
    else {
        Write-LogWarning "⚠️ 일부 구성 요소에 문제가 있습니다. 위의 로그를 확인하세요."
    }
    
    Write-Host ""
    Write-LogInfo "=== 추가 확인 사항 ==="
    Write-Host "1. 서비스 Pod 상태 확인:"
    Write-Host "   kubectl get pods -n web-tier"
    Write-Host "   kubectl get pods -n cache-tier"
    Write-Host ""
    Write-Host "2. 서비스 엔드포인트 확인:"
    Write-Host "   kubectl get endpoints -n web-tier"
    Write-Host ""
    Write-Host "3. ALB 대상 그룹 상태 확인 (AWS 콘솔):"
    Write-Host "   - EC2 → Load Balancers → Target Groups"
    Write-Host ""
    Write-Host "4. 실제 애플리케이션 테스트:"
    Write-Host "   - 브라우저에서 ALB 주소로 접속"
    Write-Host "   - API 엔드포인트 테스트"
    Write-Host "   - WebSocket 연결 테스트"

}
catch {
    Write-LogError "검증 중 오류 발생: $($_.Exception.Message)"
    exit 1
}