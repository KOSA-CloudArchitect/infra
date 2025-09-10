# Redis EKS 배포 PowerShell 스크립트
# Task 4.2: Redis Service 및 헬스체크 설정 - Windows 환경 배포 자동화

param(
    [Parameter(Position=0)]
    [ValidateSet("deploy", "status", "test", "backend", "cleanup", "help")]
    [string]$Command = "help"
)

# 색상 정의
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    White = "White"
}

# 로그 함수
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
}

# 전역 변수
$Namespace = "cache-tier"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 사전 요구사항 확인
function Test-Prerequisites {
    Write-Info "사전 요구사항 확인 중..."
    
    # kubectl 설치 확인
    try {
        $null = Get-Command kubectl -ErrorAction Stop
    }
    catch {
        Write-Error "kubectl이 설치되지 않았습니다."
        exit 1
    }
    
    # 클러스터 연결 확인
    try {
        $null = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Cluster connection failed"
        }
    }
    catch {
        Write-Error "Kubernetes 클러스터에 연결할 수 없습니다."
        exit 1
    }
    
    # 네임스페이스 존재 확인
    try {
        $null = kubectl get namespace $Namespace 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Namespace not found"
        }
    }
    catch {
        Write-Error "네임스페이스 '$Namespace'가 존재하지 않습니다."
        Write-Info "다음 명령어로 네임스페이스를 생성하세요:"
        Write-Info "kubectl apply -f k8s-manifests/01-namespaces.yaml"
        exit 1
    }
    
    Write-Success "사전 요구사항 확인 완료"
}

# Redis 배포 함수
function Deploy-Redis {
    Write-Info "Redis 클러스터 배포 시작..."
    
    # 1. ConfigMap 및 Secret 배포
    Write-Info "1/5: ConfigMap 및 Secret 배포 중..."
    kubectl apply -f "$ScriptDir/redis-configmap.yaml"
    kubectl apply -f "$ScriptDir/redis-secret.yaml"
    Write-Success "ConfigMap 및 Secret 배포 완료"
    
    # 2. Redis Master 배포
    Write-Info "2/5: Redis Master 배포 중..."
    kubectl apply -f "$ScriptDir/redis-master-statefulset.yaml"
    
    # Master Pod 준비 대기
    Write-Info "Redis Master Pod 준비 대기 중..."
    kubectl wait --for=condition=ready pod/redis-master-0 -n $Namespace --timeout=300s
    Write-Success "Redis Master 배포 완료"
    
    # 3. Redis Slave 배포
    Write-Info "3/5: Redis Slave 배포 중..."
    kubectl apply -f "$ScriptDir/redis-slave-statefulset.yaml"
    
    # Slave Pod 준비 대기
    Write-Info "Redis Slave Pod 준비 대기 중..."
    kubectl wait --for=condition=ready pod/redis-slave-0 -n $Namespace --timeout=300s
    kubectl wait --for=condition=ready pod/redis-slave-1 -n $Namespace --timeout=300s
    Write-Success "Redis Slave 배포 완료"
    
    # 4. Services 배포
    Write-Info "4/5: Redis Services 배포 중..."
    kubectl apply -f "$ScriptDir/redis-services.yaml"
    Write-Success "Redis Services 배포 완료"
    
    # 5. 모니터링 설정
    Write-Info "5/5: Redis 모니터링 설정 중..."
    kubectl apply -f "$ScriptDir/redis-monitoring.yaml"
    Write-Success "Redis 모니터링 설정 완료"
    
    Write-Success "Redis 클러스터 배포 완료!"
}

# Redis 상태 확인
function Get-RedisStatus {
    Write-Info "Redis 클러스터 상태 확인 중..."
    
    # Pod 상태 확인
    Write-Host ""
    Write-Info "=== Pod 상태 ==="
    kubectl get pods -n $Namespace -l app=redis -o wide
    
    # Service 상태 확인
    Write-Host ""
    Write-Info "=== Service 상태 ==="
    kubectl get services -n $Namespace -l app=redis
    
    # PVC 상태 확인
    Write-Host ""
    Write-Info "=== PVC 상태 ==="
    kubectl get pvc -n $Namespace
    
    # Redis 연결 테스트
    Write-Host ""
    Write-Info "=== Redis 연결 테스트 ==="
    
    # Master 연결 테스트
    Write-Info "Master 연결 테스트..."
    $masterTest = kubectl exec -n $Namespace redis-master-0 -- redis-cli -a redis-secure-password-2024 ping 2>$null
    if ($LASTEXITCODE -eq 0 -and $masterTest -eq "PONG") {
        Write-Success "✅ Master 연결 성공"
    }
    else {
        Write-Error "❌ Master 연결 실패"
    }
    
    # Slave 연결 테스트
    for ($i = 0; $i -lt 2; $i++) {
        Write-Info "Slave-$i 연결 테스트..."
        $slaveTest = kubectl exec -n $Namespace redis-slave-$i -- redis-cli -a redis-secure-password-2024 ping 2>$null
        if ($LASTEXITCODE -eq 0 -and $slaveTest -eq "PONG") {
            Write-Success "✅ Slave-$i 연결 성공"
        }
        else {
            Write-Error "❌ Slave-$i 연결 실패"
        }
    }
    
    # 복제 상태 확인
    Write-Host ""
    Write-Info "=== 복제 상태 확인 ==="
    $replicationInfo = kubectl exec -n $Namespace redis-master-0 -- redis-cli -a redis-secure-password-2024 info replication 2>$null
    $replicationInfo | Select-String -Pattern "(role|connected_slaves)"
}

# Redis 성능 테스트
function Test-RedisPerformance {
    Write-Info "Redis 성능 테스트 실행 중..."
    
    # 기본 성능 테스트
    Write-Info "기본 성능 테스트 (1000 SET/GET 작업)..."
    
    $testScript = @"
for i=1,1000 do
    redis.call('SET', 'test:key:' .. i, 'test:value:' .. i)
    redis.call('GET', 'test:key:' .. i)
end
return 'Performance test completed'
"@
    
    # 성능 테스트 실행
    $result = kubectl exec -n $Namespace redis-master-0 -- redis-cli -a redis-secure-password-2024 eval $testScript 0
    Write-Info "테스트 결과: $result"
    
    # 메모리 사용량 확인
    Write-Info "메모리 사용량 확인..."
    $memoryInfo = kubectl exec -n $Namespace redis-master-0 -- redis-cli -a redis-secure-password-2024 info memory 2>$null
    $memoryInfo | Select-String -Pattern "used_memory_human"
    
    # 테스트 데이터 정리
    $cleanupScript = @"
local keys = redis.call('KEYS', 'test:key:*')
if #keys > 0 then
    return redis.call('DEL', unpack(keys))
end
return 0
"@
    
    $cleanupResult = kubectl exec -n $Namespace redis-master-0 -- redis-cli -a redis-secure-password-2024 eval $cleanupScript 0
    Write-Info "정리된 키 개수: $cleanupResult"
    
    Write-Success "성능 테스트 완료"
}

# 백엔드 연결 테스트
function Test-BackendConnection {
    Write-Info "백엔드 연결 테스트..."
    
    # 백엔드 Pod 찾기
    $backendPod = kubectl get pods -n web-tier -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>$null
    
    if ([string]::IsNullOrEmpty($backendPod)) {
        Write-Warning "백엔드 Pod를 찾을 수 없습니다. 백엔드가 배포되지 않았을 수 있습니다."
        return
    }
    
    Write-Info "백엔드 Pod에서 Redis 연결 테스트: $backendPod"
    
    # Node.js 환경에서 Redis 연결 테스트
    $nodeScript = @"
const Redis = require('ioredis');
const client = new Redis({
    host: 'redis-service.cache-tier.svc.cluster.local',
    port: 6379,
    password: 'redis-secure-password-2024',
    connectTimeout: 5000,
    commandTimeout: 3000
});

client.ping()
    .then(result => {
        console.log('✅ 백엔드에서 Redis 연결 성공:', result);
        process.exit(0);
    })
    .catch(error => {
        console.error('❌ 백엔드에서 Redis 연결 실패:', error.message);
        process.exit(1);
    });
"@
    
    try {
        $testResult = kubectl exec -n web-tier $backendPod -- node -e $nodeScript 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "백엔드 연결 테스트 성공"
        }
        else {
            Write-Error "백엔드 연결 테스트 실패"
        }
    }
    catch {
        Write-Error "백엔드 연결 테스트 실패: $_"
    }
}

# 정리 함수
function Remove-Redis {
    Write-Warning "Redis 클러스터 정리 중..."
    
    $confirmation = Read-Host "정말로 Redis 클러스터를 삭제하시겠습니까? (y/N)"
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Info "정리 작업이 취소되었습니다."
        return
    }
    
    # 역순으로 삭제
    kubectl delete -f "$ScriptDir/redis-monitoring.yaml" --ignore-not-found=true
    kubectl delete -f "$ScriptDir/redis-services.yaml" --ignore-not-found=true
    kubectl delete -f "$ScriptDir/redis-slave-statefulset.yaml" --ignore-not-found=true
    kubectl delete -f "$ScriptDir/redis-master-statefulset.yaml" --ignore-not-found=true
    kubectl delete -f "$ScriptDir/redis-configmap.yaml" --ignore-not-found=true
    kubectl delete -f "$ScriptDir/redis-secret.yaml" --ignore-not-found=true
    
    # PVC 삭제 (데이터 손실 주의!)
    $pvcConfirmation = Read-Host "PVC도 삭제하시겠습니까? (데이터가 영구적으로 삭제됩니다) (y/N)"
    if ($pvcConfirmation -eq "y" -or $pvcConfirmation -eq "Y") {
        kubectl delete pvc -n $Namespace -l app=redis
        Write-Warning "PVC가 삭제되었습니다. 데이터가 영구적으로 손실되었습니다."
    }
    
    Write-Success "Redis 클러스터 정리 완료"
}

# 도움말 출력
function Show-Help {
    Write-Host "Redis EKS 배포 PowerShell 스크립트" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "사용법: .\deploy-redis.ps1 [COMMAND]" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor $Colors.White
    Write-Host "  deploy     Redis 클러스터 배포" -ForegroundColor $Colors.White
    Write-Host "  status     Redis 클러스터 상태 확인" -ForegroundColor $Colors.White
    Write-Host "  test       Redis 성능 테스트 실행" -ForegroundColor $Colors.White
    Write-Host "  backend    백엔드 연결 테스트" -ForegroundColor $Colors.White
    Write-Host "  cleanup    Redis 클러스터 정리" -ForegroundColor $Colors.White
    Write-Host "  help       이 도움말 출력" -ForegroundColor $Colors.White
    Write-Host ""
    Write-Host "예시:" -ForegroundColor $Colors.White
    Write-Host "  .\deploy-redis.ps1 deploy    # Redis 클러스터 배포" -ForegroundColor $Colors.White
    Write-Host "  .\deploy-redis.ps1 status    # 상태 확인" -ForegroundColor $Colors.White
    Write-Host "  .\deploy-redis.ps1 test      # 성능 테스트" -ForegroundColor $Colors.White
}

# 메인 함수
function Main {
    switch ($Command) {
        "deploy" {
            Test-Prerequisites
            Deploy-Redis
            Get-RedisStatus
        }
        "status" {
            Get-RedisStatus
        }
        "test" {
            Test-RedisPerformance
        }
        "backend" {
            Test-BackendConnection
        }
        "cleanup" {
            Remove-Redis
        }
        default {
            Show-Help
        }
    }
}

# 스크립트 실행
Main