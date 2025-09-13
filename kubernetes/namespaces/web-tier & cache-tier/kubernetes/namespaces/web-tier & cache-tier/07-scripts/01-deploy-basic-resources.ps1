# EKS Migration - Deploy Basic Resources (PowerShell)
# Task 1.2: 네임스페이스 및 기본 리소스 생성 배포 스크립트

param(
    [switch]$SkipConfirmation = $false
)

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

# Check if kubectl is available
try {
    $null = kubectl version --client --short 2>$null
    Write-Success "kubectl is available"
} catch {
    Write-Error "kubectl is not installed or not in PATH"
    exit 1
}

# Check if we can connect to the cluster
try {
    $null = kubectl cluster-info 2>$null
    Write-Success "Connected to Kubernetes cluster"
} catch {
    Write-Error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
}

Write-Info "🚀 Starting EKS basic resources deployment..."

# Get current context
$currentContext = kubectl config current-context
Write-Info "Current context: $currentContext"

# Confirm deployment
if (-not $SkipConfirmation) {
    $confirmation = Read-Host "Do you want to proceed with deployment? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Info "Deployment cancelled."
        exit 0
    }
}

# Change to k8s-manifests directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Step 1: Deploy namespaces and resource quotas
Write-Info "📁 Step 1: Creating namespaces and resource quotas..."
try {
    kubectl apply -f 01-namespaces.yaml
    Write-Success "Namespaces and resource quotas created successfully"
} catch {
    Write-Error "Failed to create namespaces and resource quotas"
    exit 1
}

# Wait for namespaces to be ready
Write-Info "⏳ Waiting for namespaces to be ready..."
Start-Sleep -Seconds 5

# Verify namespaces
Write-Info "🔍 Verifying namespaces..."
$namespaces = @("web-tier", "cache-tier", "monitoring")
foreach ($ns in $namespaces) {
    try {
        $null = kubectl get namespace $ns 2>$null
        Write-Success "Namespace '$ns' is ready"
    } catch {
        Write-Error "Namespace '$ns' is not ready"
        exit 1
    }
}

# Step 2: Deploy service accounts and RBAC
Write-Info "🔐 Step 2: Creating service accounts and RBAC..."
try {
    kubectl apply -f 02-service-accounts.yaml
    Write-Success "Service accounts and RBAC created successfully"
} catch {
    Write-Error "Failed to create service accounts and RBAC"
    exit 1
}

# Step 3: Check AWS Load Balancer Controller
Write-Info "🔍 Step 3: Checking AWS Load Balancer Controller..."
try {
    $null = kubectl get deployment aws-load-balancer-controller -n kube-system 2>$null
    Write-Success "AWS Load Balancer Controller is already installed"
    
    # Check if it's running
    $readyReplicas = kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.status.readyReplicas}' 2>$null
    $desiredReplicas = kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.spec.replicas}' 2>$null
    
    if ($readyReplicas -eq $desiredReplicas -and $readyReplicas -ne "") {
        Write-Success "AWS Load Balancer Controller is running ($readyReplicas/$desiredReplicas replicas ready)"
    } else {
        Write-Warning "AWS Load Balancer Controller is not fully ready ($readyReplicas/$desiredReplicas replicas ready)"
    }
} catch {
    Write-Warning "AWS Load Balancer Controller is not installed"
    Write-Info "To install AWS Load Balancer Controller, run:"
    Write-Info "helm repo add eks https://aws.github.io/eks-charts"
    Write-Info "helm repo update"
    Write-Info "helm install aws-load-balancer-controller eks/aws-load-balancer-controller \"
    Write-Info "  -n kube-system \"
    Write-Info "  --set clusterName=hihypipe-cluster \"
    Write-Info "  --set serviceAccount.create=false \"
    Write-Info "  --set serviceAccount.name=aws-load-balancer-controller"
    
    # Ask if user wants to install it now
    if (-not $SkipConfirmation) {
        $installChoice = Read-Host "Do you want to install AWS Load Balancer Controller now? (y/N)"
        if ($installChoice -eq 'y' -or $installChoice -eq 'Y') {
            Write-Info "Installing AWS Load Balancer Controller..."
            
            # Check if Helm is available
            try {
                $null = helm version --short 2>$null
                Write-Success "Helm is available"
                
                # Add EKS Helm repository
                helm repo add eks https://aws.github.io/eks-charts
                helm repo update
                
                # Install AWS Load Balancer Controller
                try {
                    helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
                        -n kube-system `
                        --set clusterName=hihypipe-cluster `
                        --set serviceAccount.create=false `
                        --set serviceAccount.name=aws-load-balancer-controller
                    Write-Success "AWS Load Balancer Controller installed successfully"
                } catch {
                    Write-Error "Failed to install AWS Load Balancer Controller"
                    Write-Info "You can install it manually later using the provided manifest"
                }
            } catch {
                Write-Error "Helm is not installed. Please install Helm first."
                Write-Info "You can install Helm from: https://helm.sh/docs/intro/install/"
            }
        } else {
            Write-Info "Skipping AWS Load Balancer Controller installation"
            Write-Info "You can install it later using: kubectl apply -f 03-aws-load-balancer-controller.yaml"
        }
    }
}

# Step 4: Deploy network policies
Write-Info "🔒 Step 4: Creating network policies..."
try {
    kubectl apply -f 04-network-policies.yaml
    Write-Success "Network policies created successfully"
} catch {
    Write-Warning "Failed to create network policies (this might be expected if CNI doesn't support NetworkPolicy)"
}

# Step 5: Verify deployment
Write-Info "✅ Step 5: Verifying deployment..."

Write-Info "📊 Deployment Summary:"
Write-Host "===================="

# Check namespaces
Write-Info "Namespaces:"
kubectl get namespaces -l app.kubernetes.io/part-of=review-analysis-system

# Check resource quotas
Write-Info "Resource Quotas:"
foreach ($ns in $namespaces) {
    Write-Host "  $ns:"
    try {
        $quotas = kubectl get resourcequota -n $ns --no-headers 2>$null
        if ($quotas) {
            $quotas | ForEach-Object { Write-Host "    $($_.Split()[0]): $($_.Split()[1])" }
        } else {
            Write-Host "    No resource quotas found"
        }
    } catch {
        Write-Host "    No resource quotas found"
    }
}

# Check service accounts
Write-Info "Service Accounts:"
foreach ($ns in $namespaces) {
    Write-Host "  $ns:"
    try {
        $sas = kubectl get serviceaccounts -n $ns --no-headers 2>$null | Where-Object { $_ -notmatch "default" }
        if ($sas) {
            $sas | ForEach-Object { Write-Host "    $($_.Split()[0])" }
        } else {
            Write-Host "    No custom service accounts found"
        }
    } catch {
        Write-Host "    No custom service accounts found"
    }
}

# Check network policies
Write-Info "Network Policies:"
foreach ($ns in $namespaces) {
    Write-Host "  $ns:"
    try {
        $policies = kubectl get networkpolicies -n $ns --no-headers 2>$null
        if ($policies) {
            $policies | ForEach-Object { Write-Host "    $($_.Split()[0])" }
        } else {
            Write-Host "    No network policies found"
        }
    } catch {
        Write-Host "    No network policies found"
    }
}

# Check AWS Load Balancer Controller
Write-Info "AWS Load Balancer Controller:"
try {
    kubectl get deployment aws-load-balancer-controller -n kube-system
} catch {
    Write-Host "  Not installed"
}

Write-Success "🎉 Basic resources deployment completed!"

Write-Info "Next steps:"
Write-Info "1. Verify AWS Load Balancer Controller is running properly"
Write-Info "2. Create container images and push to ECR (Task 2.1-2.4)"
Write-Info "3. Create ConfigMaps and Secrets (Task 3.1)"
Write-Info "4. Deploy applications (Task 3.2-3.4)"

Write-Info "Useful commands:"
Write-Info "kubectl get all --all-namespaces"
Write-Info "kubectl describe namespace web-tier"
Write-Info "kubectl get networkpolicies --all-namespaces"