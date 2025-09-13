# =============================================================================
# VPC 정보
# =============================================================================

# VPC IDs
output "vpc_db_id" {
  description = "ID of VPC-DB"
  value       = module.vpc_db.vpc_id
}

output "vpc_app_id" {
  description = "ID of VPC-APP"
  value       = module.vpc_app.vpc_id
}

# VPC CIDR Blocks
output "vpc_db_cidr_block" {
  description = "CIDR block of VPC-DB"
  value       = module.vpc_db.vpc_cidr_block
}

output "vpc_app_cidr_block" {
  description = "CIDR block of VPC-APP"
  value       = module.vpc_app.vpc_cidr_block
}

# =============================================================================
# 서브넷 정보
# =============================================================================

# Subnet IDs
output "vpc_db_private_subnet_ids" {
  description = "Private subnet IDs of VPC-DB"
  value       = module.vpc_db.private_subnets
}

output "vpc_app_public_subnet_ids" {
  description = "Public subnet IDs of VPC-APP"
  value       = module.vpc_app.public_subnets
}

output "vpc_app_private_subnet_ids" {
  description = "Private subnet IDs of VPC-APP"
  value       = module.vpc_app.private_subnets
}



# =============================================================================
# 라우팅 테이블 정보
# =============================================================================

# Route Table IDs
output "vpc_db_private_route_table_ids" {
  description = "Private route table IDs of VPC-DB"
  value       = module.vpc_db.private_route_table_ids
}

output "vpc_app_public_route_table_ids" {
  description = "Public route table IDs of VPC-APP"
  value       = module.vpc_app.public_route_table_ids
}

output "vpc_app_private_route_table_ids" {
  description = "Private route table IDs of VPC-APP"
  value       = module.vpc_app.private_route_table_ids
}

# =============================================================================
# Internet Gateway 정보
# =============================================================================

# Internet Gateway ID
output "vpc_app_internet_gateway_id" {
  description = "Internet Gateway ID of VPC-APP"
  value       = module.vpc_app.igw_id
}

# =============================================================================
# VPC Peering 정보
# =============================================================================

output "vpc_peering_connection_id" {
  description = "ID of VPC Peering connection between APP and DB"
  value       = aws_vpc_peering_connection.app_to_db.id
}

# =============================================================================
# 서브넷 그룹 정보
# =============================================================================

# RDS 서브넷 그룹은 현재 main.tf에 정의되지 않음
# 필요시 main.tf에 aws_db_subnet_group 리소스를 추가해야 함







# =============================================================================
# EKS 클러스터 정보
# =============================================================================

# EKS 모듈이 생성되지 않을 수 있으므로 조건부로 출력
# EKS Security Groups
output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = var.create_eks_cluster ? module.eks[0].cluster_security_group_id : null
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = var.create_eks_cluster ? module.eks[0].node_security_group_id : null
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = var.create_eks_cluster ? module.eks[0].cluster_id : null
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = var.create_eks_cluster ? module.eks[0].cluster_arn : null
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = var.create_eks_cluster ? module.eks[0].cluster_endpoint : null
}

output "eks_cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = var.create_eks_cluster ? module.eks[0].cluster_oidc_issuer_url : null
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = var.create_eks_cluster ? module.eks[0].cluster_certificate_authority_data : null
}

# EKS Node Groups
output "eks_nodegroup_ids" {
  description = "EKS managed node group IDs"
  value       = var.create_eks_cluster ? module.eks[0].eks_managed_node_groups_autoscaling_group_names : null
}



# =============================================================================
# 네트워크 요약 정보
# =============================================================================

# =============================================================================
# 사용법 안내
# =============================================================================

output "usage_instructions" {
  description = "Instructions for using the infrastructure"
  value = {
    eks_kubeconfig = var.create_eks_cluster ? "aws eks update-kubeconfig --name ${var.eks_cluster_name} --region ${var.aws_region}" : "EKS cluster is not created"
    vpc_peering_status = "VPC Peering between APP and DB VPCs is automatically configured"
    cost_optimization = "NAT Gateway is enabled for private subnets. Use your own Bastion Host for external access."
    note = "Bastion Host is not included in this Terraform configuration. Please configure separately."
  }
}
