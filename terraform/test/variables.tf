# =============================================================================
# 기본 설정
# =============================================================================

# AWS Region
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# Project Name
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "hihypipe"
}

# Environment
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

# Owner
variable "owner" {
  description = "Resource owner"
  type        = string
  default     = "hihypipe-team"
}

# Cost Center
variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "hihypipe-network"
}

# =============================================================================
# 가용영역 및 네트워크 설정
# =============================================================================

# Availability Zones
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}

# VPC CIDR Blocks
variable "vpc_db_cidr" {
  description = "CIDR block for VPC-DB"
  type        = string
  default     = "172.20.0.0/17"
}

variable "vpc_app_cidr" {
  description = "CIDR block for VPC-APP"
  type        = string
  default     = "172.20.128.0/17"
}

# VPC-DB Private Subnets
variable "vpc_db_private_subnets" {
  description = "Private subnets for VPC-DB"
  type        = list(string)
  default     = [
    "172.20.0.0/20",    # Private-DB AZ-a
    "172.20.16.0/20",   # Private-DB AZ-b
    "172.20.32.0/20",   # Private-DB AZ-c
  ]
}

# VPC-APP Public Subnets
variable "vpc_app_public_subnets" {
  description = "Public subnets for VPC-APP"
  type        = list(string)
  default     = [
    "172.20.128.0/20",  # Public AZ-a
    "172.20.144.0/20",  # Public AZ-b
    "172.20.160.0/20"   # Public AZ-c
  ]
}

# VPC-APP Private Subnets
variable "vpc_app_private_subnets" {
  description = "Private subnets for VPC-APP"
  type        = list(string)
  default     = [
    "172.20.176.0/20",  # Private AZ-a
    "172.20.192.0/20",  # Private AZ-b
    "172.20.208.0/20"   # Private AZ-c
  ]
}

# =============================================================================
# On-premises 설정
# =============================================================================

# On-premises CIDR
variable "onprem_cidr" {
  description = "On-premises network CIDR"
  type        = string
  default     = "10.128.0.0/19"
}

# =============================================================================
# RDS PostgreSQL 설정
# =============================================================================

# RDS PostgreSQL 생성 여부
variable "create_rds_postgresql" {
  description = "Whether to create RDS PostgreSQL instance"
  type        = bool
  default     = true
}

# 데이터베이스 비밀번호
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# =============================================================================
# 단방향 통신 설정
# =============================================================================

# PUBLIC → ONPREM 통신은 허용되지만, ONPREM → PUBLIC은 차단됨
# 별도의 VPN 서버 설정이 필요하지 않음
