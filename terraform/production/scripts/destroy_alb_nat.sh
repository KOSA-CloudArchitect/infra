#!/usr/bin/env bash
set -euo pipefail

# This script destroys only Jenkins ALB resources and the NAT route + NAT Gateway.
# It intentionally keeps the NAT EIP allocated for later reuse.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "[INFO] Working dir: $(pwd)"

# Ensure backend and providers are initialized
terraform init -input=false -upgrade

echo "[INFO] Current workspace: $(terraform workspace show)"

echo "[INFO] Destroying ALB listener..."
terraform destroy -target='aws_lb_listener.jenkins_listener[0]' -auto-approve

echo "[INFO] Destroying ALB target group attachment..."
terraform destroy -target='aws_lb_target_group_attachment.jenkins_attachment[0]' -auto-approve

echo "[INFO] Destroying ALB target group..."
terraform destroy -target='aws_lb_target_group.jenkins_tg[0]' -auto-approve

echo "[INFO] Destroying ALB..."
terraform destroy -target='aws_lb.jenkins_alb[0]' -auto-approve

echo "[INFO] Destroying NAT private route to NAT Gateway..."
terraform destroy -target='module.vpc_app.aws_route.private_nat_gateway[0]' -auto-approve 

echo "[INFO] Destroying NAT Gateway (EIP will remain)..."
terraform destroy -target='module.vpc_app.aws_nat_gateway.this[0]' -auto-approve

echo "[INFO] Done. ALB and NAT GW removed. NAT EIP retained."





