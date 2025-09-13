#!/bin/bash

# EKS Migration - Deploy Basic Resources
# Task 1.2: 네임스페이스 및 기본 리소스 생성 배포 스크립트

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_info "🚀 Starting EKS basic resources deployment..."

# Get current context
CURRENT_CONTEXT=$(kubectl config current-context)
print_info "Current context: $CURRENT_CONTEXT"

# Confirm deployment
read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Deployment cancelled."
    exit 0
fi

# Step 1: Deploy namespaces and resource quotas
print_info "📁 Step 1: Creating namespaces and resource quotas..."
if kubectl apply -f 01-namespaces.yaml; then
    print_success "Namespaces and resource quotas created successfully"
else
    print_error "Failed to create namespaces and resource quotas"
    exit 1
fi

# Wait for namespaces to be ready
print_info "⏳ Waiting for namespaces to be ready..."
sleep 5

# Verify namespaces
print_info "🔍 Verifying namespaces..."
NAMESPACES=("backend" "redis" "kafka")
for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        print_success "Namespace '$ns' is ready"
    else
        print_error "Namespace '$ns' is not ready"
        exit 1
    fi
done

# Step 2: Deploy service accounts and RBAC
print_info "🔐 Step 2: Creating service accounts and RBAC..."
if kubectl apply -f 02-service-accounts.yaml; then
    print_success "Service accounts and RBAC created successfully"
else
    print_error "Failed to create service accounts and RBAC"
    exit 1
fi

# Step 3: Check AWS Load Balancer Controller
print_info "🔍 Step 3: Checking AWS Load Balancer Controller..."
if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
    print_success "AWS Load Balancer Controller is already installed"
    
    # Check if it's running
    READY_REPLICAS=$(kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.spec.replicas}')
    
    if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ] && [ "$READY_REPLICAS" != "" ]; then
        print_success "AWS Load Balancer Controller is running ($READY_REPLICAS/$DESIRED_REPLICAS replicas ready)"
    else
        print_warning "AWS Load Balancer Controller is not fully ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas ready)"
    fi
else
    print_warning "AWS Load Balancer Controller is not installed"
    print_info "To install AWS Load Balancer Controller, run:"
    print_info "helm repo add eks https://aws.github.io/eks-charts"
    print_info "helm repo update"
    print_info "helm install aws-load-balancer-controller eks/aws-load-balancer-controller \\"
    print_info "  -n kube-system \\"
    print_info "  --set clusterName=hihypipe-cluster \\"
    print_info "  --set serviceAccount.create=false \\"
    print_info "  --set serviceAccount.name=aws-load-balancer-controller"
    
    # Ask if user wants to install it now
    read -p "Do you want to install AWS Load Balancer Controller now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing AWS Load Balancer Controller..."
        
        # Check if Helm is available
        if ! command -v helm &> /dev/null; then
            print_error "Helm is not installed. Please install Helm first."
            print_info "You can install Helm from: https://helm.sh/docs/intro/install/"
        else
            # Add EKS Helm repository
            helm repo add eks https://aws.github.io/eks-charts
            helm repo update
            
            # Install AWS Load Balancer Controller
            if helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                -n kube-system \
                --set clusterName=hihypipe-cluster \
                --set serviceAccount.create=false \
                --set serviceAccount.name=aws-load-balancer-controller; then
                print_success "AWS Load Balancer Controller installed successfully"
            else
                print_error "Failed to install AWS Load Balancer Controller"
                print_info "You can install it manually later using the provided manifest"
            fi
        fi
    else
        print_info "Skipping AWS Load Balancer Controller installation"
        print_info "You can install it later using: kubectl apply -f 03-aws-load-balancer-controller.yaml"
    fi
fi

# Step 4: Deploy network policies
print_info "🔒 Step 4: Creating network policies..."
if kubectl apply -f 04-network-policies.yaml; then
    print_success "Network policies created successfully"
else
    print_warning "Failed to create network policies (this might be expected if CNI doesn't support NetworkPolicy)"
fi

# Step 5: Verify deployment
print_info "✅ Step 5: Verifying deployment..."

print_info "📊 Deployment Summary:"
echo "===================="

# Check namespaces
print_info "Namespaces:"
kubectl get namespaces -l app.kubernetes.io/part-of=review-analysis-system

# Check resource quotas
print_info "Resource Quotas:"
for ns in "${NAMESPACES[@]}"; do
    echo "  $ns:"
    kubectl get resourcequota -n "$ns" --no-headers 2>/dev/null | awk '{print "    " $1 ": " $2}' || echo "    No resource quotas found"
done

# Check service accounts
print_info "Service Accounts:"
for ns in "${NAMESPACES[@]}"; do
    echo "  $ns:"
    kubectl get serviceaccounts -n "$ns" --no-headers 2>/dev/null | grep -v default | awk '{print "    " $1}' || echo "    No custom service accounts found"
done

# Check network policies
print_info "Network Policies:"
for ns in "${NAMESPACES[@]}"; do
    echo "  $ns:"
    kubectl get networkpolicies -n "$ns" --no-headers 2>/dev/null | awk '{print "    " $1}' || echo "    No network policies found"
done

# Check AWS Load Balancer Controller
print_info "AWS Load Balancer Controller:"
if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
    kubectl get deployment aws-load-balancer-controller -n kube-system
else
    echo "  Not installed"
fi

print_success "🎉 Basic resources deployment completed!"

print_info "Next steps:"
print_info "1. Verify AWS Load Balancer Controller is running properly"
print_info "2. Create container images and push to ECR (Task 2.1-2.4)"
print_info "3. Create ConfigMaps and Secrets (Task 3.1)"
print_info "4. Deploy applications (Task 3.2-3.4)"

print_info "Useful commands:"
print_info "kubectl get all --all-namespaces"
print_info "kubectl describe namespace backend"
print_info "kubectl get networkpolicies --all-namespaces"