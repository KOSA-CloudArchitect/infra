# =============================================================================
# VPC 출력
# =============================================================================

output "vpc_app_id" {
  description = "VPC-APP ID"
  value       = module.vpc_app.vpc_id
}

output "vpc_db_id" {
  description = "VPC-DB ID"
  value       = module.vpc_db.vpc_id
}

output "vpc_app_cidr" {
  description = "VPC-APP CIDR"
  value       = module.vpc_app.vpc_cidr_block
}

output "vpc_db_cidr" {
  description = "VPC-DB CIDR"
  value       = module.vpc_db.vpc_cidr_block
}

# =============================================================================
# Subnet 출력
# =============================================================================

output "vpc_app_public_subnets" {
  description = "VPC-APP Public Subnets"
  value       = module.vpc_app.public_subnets
}

output "vpc_app_private_subnets" {
  description = "VPC-APP Private Subnets"
  value       = module.vpc_app.private_subnets
}

output "vpc_db_private_subnets" {
  description = "VPC-DB Private Subnets"
  value       = module.vpc_db.private_subnets
}

# =============================================================================
# Security Groups 출력
# =============================================================================

output "rds_postgresql_security_group_id" {
  description = "RDS PostgreSQL Security Group ID"
  value       = aws_security_group.rds_postgresql.id
}

output "vpn_security_group_id" {
  description = "VPN Security Group ID"
  value       = aws_security_group.vpn.id
}

# =============================================================================
# RDS PostgreSQL 출력
# =============================================================================

output "rds_postgresql_endpoint" {
  description = "RDS PostgreSQL Endpoint"
  value       = var.create_rds_postgresql ? aws_db_instance.postgresql[0].endpoint : null
}

output "rds_postgresql_port" {
  description = "RDS PostgreSQL Port"
  value       = var.create_rds_postgresql ? aws_db_instance.postgresql[0].port : null
}

output "rds_postgresql_database_name" {
  description = "RDS PostgreSQL Database Name"
  value       = var.create_rds_postgresql ? aws_db_instance.postgresql[0].db_name : null
}

output "rds_postgresql_username" {
  description = "RDS PostgreSQL Username"
  value       = var.create_rds_postgresql ? aws_db_instance.postgresql[0].username : null
}

output "rds_postgresql_instance_class" {
  description = "RDS PostgreSQL Instance Class"
  value       = var.create_rds_postgresql ? aws_db_instance.postgresql[0].instance_class : null
}

# =============================================================================
# 단방향 통신 정보
# =============================================================================

output "communication_direction" {
  description = "Communication direction information"
  value = {
    public_to_onprem = "Allowed"
    onprem_to_public = "Blocked"
    note = "No VPN server required for this setup"
  }
}

# =============================================================================
# VPC Peering 출력
# =============================================================================

output "vpc_peering_connection_id" {
  description = "VPC Peering Connection ID"
  value       = aws_vpc_peering_connection.app_to_db.id
}

# =============================================================================
# 연결 정보 출력
# =============================================================================

output "database_connection_string" {
  description = "Database Connection String (without password)"
  value       = var.create_rds_postgresql ? "postgresql://${aws_db_instance.postgresql[0].username}@${aws_db_instance.postgresql[0].endpoint}:${aws_db_instance.postgresql[0].port}/${aws_db_instance.postgresql[0].db_name}" : null
}

output "onprem_network_info" {
  description = "On-premises network information"
  value = {
    cidr = var.onprem_cidr
    note = "This network can receive traffic from AWS but cannot initiate connections to AWS"
  }
}

# =============================================================================
# 비용 최적화 정보
# =============================================================================

output "cost_optimization_info" {
  description = "Cost Optimization Information"
  value = {
    rds_instance_class = var.create_rds_postgresql ? aws_db_instance.postgresql[0].instance_class : null
    storage_encrypted  = var.create_rds_postgresql ? aws_db_instance.postgresql[0].storage_encrypted : null
    performance_insights = var.create_rds_postgresql ? aws_db_instance.postgresql[0].performance_insights_enabled : null
    monitoring = var.create_rds_postgresql ? aws_db_instance.postgresql[0].monitoring_interval : null
    note = "VPN server removed - cost optimized for RDS only"
  }
}
