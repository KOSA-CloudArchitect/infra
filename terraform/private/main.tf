terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Name        = var.project_name
      Environment = var.environment
      Owner       = var.owner
      CostCenter  = var.cost_center
      Project     = var.project_name
    }
  }
}


# =============================================================================
# VPC 구성
# =============================================================================

# VPC-APP (애플리케이션용)
module "vpc_app" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "vpc-app"
  cidr = var.vpc_app_cidr
  
  azs             = var.availability_zones
  public_subnets  = var.vpc_app_public_subnets
  private_subnets = var.vpc_app_private_subnets

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  #enable_dns_hostnames    = true
  #enable_dns_support      = true
  enable_nat_gateway      = true
  single_nat_gateway      = true

  tags = {
    Name        = "vpc-app"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Purpose     = "Application"
  }
}


# VPC-DB (데이터베이스용)
module "vpc_db" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"
  
  name = "vpc-db"
  cidr = var.vpc_db_cidr
  
  azs             = var.availability_zones
  private_subnets = var.vpc_db_private_subnets
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # VPC-DB는 IGW와 NAT Gateway 모두 비활성화 (완전 격리)
  create_igw          = false
  enable_nat_gateway  = false
  
}

# =============================================================================
# Security Groups for VPC Endpoints
# =============================================================================

# VPC Endpoints용 Security Group
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "vpc-endpoints"
  vpc_id      = module.vpc_app.vpc_id
  
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [var.vpc_app_cidr]
    description = "HTTPS access from VPC-APP"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "vpc-endpoints"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# =============================================================================
# VPC Peering (App과 DB VPC 간 통신)
# =============================================================================

resource "aws_vpc_peering_connection" "app_to_db" {
  vpc_id      = module.vpc_app.vpc_id
  peer_vpc_id = module.vpc_db.vpc_id
  
  auto_accept = true
  
  tags = {
    Name        = "vpc-peering-app-to-db"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# VPC Peering 라우팅 테이블 업데이트
resource "aws_route" "app_to_db" {
  count                     = length(module.vpc_app.private_route_table_ids)
  route_table_id            = module.vpc_app.private_route_table_ids[count.index]
  destination_cidr_block    = var.vpc_db_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_db.id
}

resource "aws_route" "db_to_app" {
  count                     = length(module.vpc_db.private_route_table_ids)
  route_table_id            = module.vpc_db.private_route_table_ids[count.index]
  destination_cidr_block    = var.vpc_app_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_db.id
}

# =============================================================================
# VPC Endpoints (비용 최소화를 위해 필수적인 것만)
# =============================================================================


# =============================================================================
# Subnet Groups for RDS
# =============================================================================

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = [module.vpc_db.private_subnets[0], module.vpc_db.private_subnets[1]]  # AZ-a, AZ-b만 사용
  
  tags = {
    Name        = "${var.project_name}-rds-subnet-group"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}




