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

output "rds_subnet_group_id" {
  description = "ID of RDS subnet group"
  value       = aws_db_subnet_group.rds.id
}







# =============================================================================
# EKS 클러스터 정보
# =============================================================================

# EKS Security Groups
output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

# EKS Node Groups
output "eks_nodegroup_ids" {
  description = "EKS managed node group IDs"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
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
    eks_kubeconfig = "aws eks update-kubeconfig --name ${var.eks_cluster_name} --region ${var.aws_region}"
    vpc_peering_status = "VPC Peering between APP and DB VPCs is automatically configured"
    cost_optimization = "NAT Gateway is disabled to minimize costs. Use your own Bastion Host for external access."
    note = "Bastion Host is not included in this Terraform configuration. Please configure separately."
  }
}
