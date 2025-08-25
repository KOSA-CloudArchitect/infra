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
  default     = ""
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
  default     = "172.16.0.0/17"
}

variable "vpc_app_cidr" {
  description = "CIDR block for VPC-APP"
  type        = string
  default     = "172.16.128.0/17"
}

# VPC-DB Private Subnets
variable "vpc_db_private_subnets" {
  description = "Private subnets for VPC-DB"
  type        = list(string)
  default     = [
    "172.16.0.0/20",    # Private-DB AZ-a
    "172.16.16.0/20",   # Private-DB AZ-b
    "172.16.32.0/20",   # Private-DB AZ-c
  ]
}

# VPC-APP Public Subnets
variable "vpc_app_public_subnets" {
  description = "Public subnets for VPC-APP"
  type        = list(string)
  default     = [
    "172.16.128.0/20",  # Public AZ-a
    "172.16.144.0/20",  # Public AZ-b
    "172.16.160.0/20"   # Public AZ-c
  ]
}

# VPC-APP Private Subnets
variable "vpc_app_private_subnets" {
  description = "Private subnets for VPC-APP"
  type        = list(string)
  default     = [
    "172.16.176.0/20",  # Private AZ-a
    "172.16.192.0/20",  # Private AZ-b
    "172.16.208.0/20"   # Private AZ-c
  ]
}

# =============================================================================
# EKS 설정
# =============================================================================

# EKS Cluster Configuration
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "hihypipe-cluster"
}



# =============================================================================
# 태그 설정
# =============================================================================

# Common Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Project     = "hihypipe"
    ManagedBy   = "terraform"
    Environment = ""
    Purpose     = "Infrastructure"
  }
}
