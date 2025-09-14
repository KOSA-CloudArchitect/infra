# EKS Migration - Verify Basic Resources
# Task 1.2: 네임스페이스 및 기본 리소스 검증 스크립트

# Colors for output
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param([string]$Message, [string]$Color)
    Write-Host "$Color$Message$Reset"
}

function Write-Info { param([string]$Message) Write-ColorOutput "[INFO] $Message" $Blue }
function Write-Success { param([string]$Message) Write-ColorOutput "[SUCCESS] $Message" $Green }
function Write-Warning { param([string]$Message) Write-ColorOutput "[WARNING] $Message" $Yellow }
function Write-Error { param([string]$Message) Write-ColorOutput "[ERROR] $Message" $Red }

Write-Info "🔍 Starting EKS basic resources verification..."

# Check kubectl connectivity
try {
    $clusterInfo = kubectl cluster-info 2>$null
    Write-Success "Connected to Kubernetes cluster"
    Write-Info "Cluster info: $($clusterInfo.Split("`n")[0])"
} catch {
    Write-Error "Cannot connect to Kubernetes cluster"
    exit 1
}

$verificationResults = @{
    "Namespaces" = $false
    "ResourceQuotas" = $false
    "ServiceAccounts" = $false
    "RBAC" = $false
    "NetworkPolicies" = $false
    "LoadBalancerController" = $false
}

# 1. Verify Namespaces
Write-Info "📁 1. Verifying namespaces..."
$requiredNamespaces = @("backend", "redis", "kafka")
$allNamespacesExist = $true

foreach ($ns in $requiredNamespaces) {
    try {
        $nsInfo = kubectl get namespace $ns -o json 2>$null | ConvertFrom-Json
        if ($nsInfo.status.phase -eq "Active") {
            Write-Success "✅ Namespace '$ns' is active"
        } else {
            Write-Warning "⚠️ Namespace '$ns' exists but not active (status: $($nsInfo.status.phase))"
            $allNamespacesExist = $false
        }
        
        # Check labels
        $expectedLabels = @{
            "app.kubernetes.io/part-of" = "review-analysis-system"
            "environment" = "production"
        }
        
        foreach ($label in $expectedLabels.GetEnumerator()) {
            if ($nsInfo.metadata.labels.$($label.Key) -eq $label.Value) {
                Write-Success "  ✅ Label $($label.Key)=$($label.Value) is correct"
            } else {
                Write-Warning "  ⚠️ Label $($label.Key) is missing or incorrect"
            }
        }
    } catch {
        Write-Error "❌ Namespace '$ns' does not exist"
        $allNamespacesExist = $false
    }
}

$verificationResults["Namespaces"] = $allNamespacesExist

# 2. Verify Resource Quotas
Write-Info "📊 2. Verifying resource quotas..."
$allQuotasExist = $true

foreach ($ns in $requiredNamespaces) {
    try {
        $quota = kubectl get resourcequota -n $ns --no-headers 2>$null
        if ($quota) {
            Write-Success "✅ Resource quota exists in namespace '$ns'"
            
            # Get detailed quota information
            $quotaDetails = kubectl get resourcequota -n $ns -o json 2>$null | ConvertFrom-Json
            if ($quotaDetails.items.Count -gt 0) {
                $quotaItem = $quotaDetails.items[0]
                Write-Info "  CPU requests: $($quotaItem.spec.hard.'requests.cpu')"
                Write-Info "  Memory requests: $($quotaItem.spec.hard.'requests.memory')"
                Write-Info "  CPU limits: $($quotaItem.spec.hard.'limits.cpu')"
                Write-Info "  Memory limits: $($quotaItem.spec.hard.'limits.memory')"
            }
        } else {
            Write-Warning "⚠️ No resource quota found in namespace '$ns'"
            $allQuotasExist = $false
        }
    } catch {
        Write-Error "❌ Failed to check resource quota in namespace '$ns'"
        $allQuotasExist = $false
    }
}

$verificationResults["ResourceQuotas"] = $allQuotasExist

# 3. Verify Service Accounts
Write-Info "🔐 3. Verifying service accounts..."
$expectedServiceAccounts = @{
    "backend" = "backend-sa"
    "redis" = "redis-sa"
    "kafka" = "kafka-sa"
}

$allServiceAccountsExist = $true

foreach ($ns in $expectedServiceAccounts.GetEnumerator()) {
    try {
        $sa = kubectl get serviceaccount $ns.Value -n $ns.Key -o json 2>$null | ConvertFrom-Json
        Write-Success "✅ Service account '$($ns.Value)' exists in namespace '$($ns.Key)'"
        
        # Check if service account has secrets (tokens)
        if ($sa.secrets -and $sa.secrets.Count -gt 0) {
            Write-Success "  ✅ Service account has $($sa.secrets.Count) secret(s)"
        } else {
            Write-Info "  ℹ️ Service account has no secrets (normal for newer Kubernetes versions)"
        }
    } catch {
        Write-Error "❌ Service account '$($ns.Value)' does not exist in namespace '$($ns.Key)'"
        $allServiceAccountsExist = $false
    }
}

$verificationResults["ServiceAccounts"] = $allServiceAccountsExist

# 4. Verify RBAC (ClusterRoles and Bindings)
Write-Info "🔒 4. Verifying RBAC..."
$expectedClusterRoles = @("backend-role", "redis-role", "kafka-role")
$expectedClusterRoleBindings = @("backend-binding", "redis-binding", "kafka-binding")

$allRBACExists = $true

# Check ClusterRoles
foreach ($role in $expectedClusterRoles) {
    try {
        $null = kubectl get clusterrole $role 2>$null
        Write-Success "✅ ClusterRole '$role' exists"
    } catch {
        Write-Error "❌ ClusterRole '$role' does not exist"
        $allRBACExists = $false
    }
}

# Check ClusterRoleBindings
foreach ($binding in $expectedClusterRoleBindings) {
    try {
        $null = kubectl get clusterrolebinding $binding 2>$null
        Write-Success "✅ ClusterRoleBinding '$binding' exists"
    } catch {
        Write-Error "❌ ClusterRoleBinding '$binding' does not exist"
        $allRBACExists = $false
    }
}

# Check namespace-specific Roles and RoleBindings
$expectedRoles = @{
    "backend" = "backend-namespace-role"
    "redis" = "redis-namespace-role"
    "kafka" = "kafka-namespace-role"
}

foreach ($ns in $expectedRoles.GetEnumerator()) {
    try {
        $null = kubectl get role $ns.Value -n $ns.Key 2>$null
        Write-Success "✅ Role '$($ns.Value)' exists in namespace '$($ns.Key)'"
    } catch {
        Write-Error "❌ Role '$($ns.Value)' does not exist in namespace '$($ns.Key)'"
        $allRBACExists = $false
    }
    
    try {
        $bindingName = $ns.Value -replace "-role$", "-binding"
        $null = kubectl get rolebinding $bindingName -n $ns.Key 2>$null
        Write-Success "✅ RoleBinding '$bindingName' exists in namespace '$($ns.Key)'"
    } catch {
        Write-Error "❌ RoleBinding '$bindingName' does not exist in namespace '$($ns.Key)'"
        $allRBACExists = $false
    }
}

$verificationResults["RBAC"] = $allRBACExists

# 5. Verify Network Policies
Write-Info "🔒 5. Verifying network policies..."
$allNetworkPoliciesExist = $true

foreach ($ns in $requiredNamespaces) {
    try {
        $policies = kubectl get networkpolicies -n $ns --no-headers 2>$null
        if ($policies) {
            $policyCount = ($policies | Measure-Object).Count
            Write-Success "✅ $policyCount network policy(ies) exist in namespace '$ns'"
            
            # List policy names
            $policyNames = kubectl get networkpolicies -n $ns -o jsonpath='{.items[*].metadata.name}' 2>$null
            Write-Info "  Policies: $policyNames"
        } else {
            Write-Warning "⚠️ No network policies found in namespace '$ns'"
            $allNetworkPoliciesExist = $false
        }
    } catch {
        Write-Warning "⚠️ Failed to check network policies in namespace '$ns' (CNI might not support NetworkPolicy)"
    }
}

$verificationResults["NetworkPolicies"] = $allNetworkPoliciesExist

# 6. Verify AWS Load Balancer Controller
Write-Info "🔍 6. Verifying AWS Load Balancer Controller..."
try {
    $deployment = kubectl get deployment aws-load-balancer-controller -n kube-system -o json 2>$null | ConvertFrom-Json
    
    if ($deployment) {
        $readyReplicas = $deployment.status.readyReplicas
        $desiredReplicas = $deployment.spec.replicas
        
        if ($readyReplicas -eq $desiredReplicas -and $readyReplicas -gt 0) {
            Write-Success "✅ AWS Load Balancer Controller is running ($readyReplicas/$desiredReplicas replicas ready)"
            $verificationResults["LoadBalancerController"] = $true
            
            # Check controller version
            $image = $deployment.spec.template.spec.containers[0].image
            Write-Info "  Controller image: $image"
            
            # Check if IngressClass exists
            try {
                $ingressClass = kubectl get ingressclass alb 2>$null
                if ($ingressClass) {
                    Write-Success "  ✅ IngressClass 'alb' exists"
                } else {
                    Write-Warning "  ⚠️ IngressClass 'alb' does not exist"
                }
            } catch {
                Write-Warning "  ⚠️ Failed to check IngressClass 'alb'"
            }
        } else {
            Write-Warning "⚠️ AWS Load Balancer Controller is not fully ready ($readyReplicas/$desiredReplicas replicas ready)"
        }
    } else {
        Write-Warning "⚠️ AWS Load Balancer Controller deployment not found"
    }
} catch {
    Write-Warning "⚠️ AWS Load Balancer Controller is not installed"
    Write-Info "  Install it using: helm install aws-load-balancer-controller eks/aws-load-balancer-controller"
}

# 7. Additional Checks
Write-Info "🔍 7. Additional checks..."

# Check node readiness
Write-Info "Node status:"
try {
    $nodes = kubectl get nodes --no-headers 2>$null
    $nodeCount = ($nodes | Measure-Object).Count
    $readyNodes = ($nodes | Where-Object { $_ -match "Ready" } | Measure-Object).Count
    
    Write-Info "  Total nodes: $nodeCount"
    Write-Info "  Ready nodes: $readyNodes"
    
    if ($readyNodes -eq $nodeCount -and $nodeCount -gt 0) {
        Write-Success "  ✅ All nodes are ready"
    } else {
        Write-Warning "  ⚠️ Some nodes are not ready"
    }
} catch {
    Write-Warning "  ⚠️ Failed to check node status"
}

# Check system pods
Write-Info "System pods status:"
try {
    $systemPods = kubectl get pods -n kube-system --no-headers 2>$null
    $totalPods = ($systemPods | Measure-Object).Count
    $runningPods = ($systemPods | Where-Object { $_ -match "Running" } | Measure-Object).Count
    
    Write-Info "  Total system pods: $totalPods"
    Write-Info "  Running system pods: $runningPods"
    
    if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
        Write-Success "  ✅ All system pods are running"
    } else {
        Write-Warning "  ⚠️ Some system pods are not running"
    }
} catch {
    Write-Warning "  ⚠️ Failed to check system pods status"
}

# Summary
Write-Info "📋 Verification Summary:"
Write-Host "======================"

$passedChecks = 0
$totalChecks = $verificationResults.Count

foreach ($check in $verificationResults.GetEnumerator()) {
    if ($check.Value) {
        Write-Success "✅ $($check.Key): PASSED"
        $passedChecks++
    } else {
        Write-Error "❌ $($check.Key): FAILED"
    }
}

Write-Host ""
if ($passedChecks -eq $totalChecks) {
    Write-Success "🎉 All verification checks passed! ($passedChecks/$totalChecks)"
    Write-Success "Basic resources are ready for the next deployment phase."
} else {
    Write-Warning "⚠️ $passedChecks out of $totalChecks checks passed."
    Write-Info "Please review the failed checks and fix any issues before proceeding."
}

Write-Info ""
Write-Info "Next steps if all checks passed:"
Write-Info "1. Create ECR repositories (Task 2.1)"
Write-Info "2. Build and push container images (Task 2.2-2.4)"
Write-Info "3. Create ConfigMaps and Secrets (Task 3.1)"
Write-Info "4. Deploy applications (Task 3.2-3.4)"

# Return exit code based on verification results
if ($passedChecks -eq $totalChecks) {
    exit 0
} else {
    exit 1
}