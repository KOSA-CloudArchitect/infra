#!/usr/bin/env bash
set -euo pipefail

# This script (re)creates only Jenkins ALB resources and the NAT Gateway + route.
# It assumes VPC, subnets, security groups already exist. It reuses existing NAT EIP if present.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "[INFO] Working dir: $(pwd)"

# Ensure backend and providers are initialized
terraform init -input=false -upgrade

echo "[INFO] Current workspace: $(terraform workspace show)"

echo "[INFO] Creating NAT Gateway (will reuse allocated EIP if managed by state)..."
terraform apply -target='module.vpc_app.aws_nat_gateway.this[0]' -auto-approve

echo "[INFO] Creating NAT private route to NAT Gateway..."
terraform apply -target='module.vpc_app.aws_route.private_nat_gateway[0]' -auto-approve

echo "[INFO] Creating Jenkins ALB..."
terraform apply -target='aws_lb.jenkins_alb[0]' -auto-approve

echo "[INFO] Creating Jenkins Target Group..."
terraform apply -target='aws_lb_target_group.jenkins_tg[0]' -auto-approve

echo "[INFO] Creating Jenkins Listener..."
terraform apply -target='aws_lb_listener.jenkins_listener[0]' -auto-approve

echo "[INFO] Attaching Jenkins Instance to Target Group..."
terraform apply -target='aws_lb_target_group_attachment.jenkins_attachment[0]' -auto-approve

echo "[INFO] Done. NAT GW, route, and Jenkins ALB stack created."



