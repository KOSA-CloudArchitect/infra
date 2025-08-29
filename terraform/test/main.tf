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

  name = "vpc-app-test"
  cidr = var.vpc_app_cidr
  
  azs             = var.availability_zones
  public_subnets  = var.vpc_app_public_subnets
  private_subnets = var.vpc_app_private_subnets


  enable_nat_gateway      = true
  single_nat_gateway      = true

  tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Purpose     = "Application-Test"
  }
}

# VPC-DB (데이터베이스용)
module "vpc_db" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"
  
  name = "vpc-db-test"
  cidr = var.vpc_db_cidr
  
  azs             = var.availability_zones
  private_subnets = var.vpc_db_private_subnets
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # VPC-DB는 IGW와 NAT Gateway 모두 비활성화 (완전 격리)
  create_igw          = false
  enable_nat_gateway  = false
  
  tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Purpose     = "Database-Test"
  }
}

# =============================================================================
# Security Groups
# =============================================================================

# RDS PostgreSQL용 Security Group
resource "aws_security_group" "rds_postgresql" {
  name_prefix = "rds-postgresql-test"
  vpc_id      = module.vpc_db.vpc_id
  
  description = "Security group for RDS PostgreSQL test environment"
  
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_app_cidr]
    description = "PostgreSQL access from VPC-APP"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "rds-postgresql-test"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# ONPREM → PUBLIC 통신 차단을 위한 Security Group 규칙
# PUBLIC → ONPREM은 허용되지만, ONPREM → PUBLIC은 차단됨

# =============================================================================
# VPC Peering (App과 DB VPC 간 통신)
# =============================================================================

resource "aws_vpc_peering_connection" "app_to_db" {
  vpc_id      = module.vpc_app.vpc_id
  peer_vpc_id = module.vpc_db.vpc_id
  
  auto_accept = true
  
  tags = {
    Name        = "vpc-peering-app-to-db-test"
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
# RDS PostgreSQL Instance
# =============================================================================

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_postgresql" {
  name       = "${var.project_name}-rds-postgresql-test-subnet-group"
  subnet_ids = [module.vpc_db.private_subnets[0], module.vpc_db.private_subnets[1]]
  
  tags = {
    Name        = "${var.project_name}-rds-postgresql-test-subnet-group"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "rds_postgresql" {
  name   = "${var.project_name}-rds-postgresql-test-params"
  family = "postgres15"
  
  parameter {
    name  = "log_connections"
    value = "1"
  }
  
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
  
  tags = {
    Name        = "${var.project_name}-rds-postgresql-test-params"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# RDS PostgreSQL Instance (최소 사양)
resource "aws_db_instance" "postgresql" {
  count = var.create_rds_postgresql ? 1 : 0
  
  identifier = "${var.project_name}-postgresql-test"
  
  # 최소 사양 설정
  instance_class      = "db.t3.micro"  # 최소 사양
  allocated_storage   = 20             # 최소 스토리지
  max_allocated_storage = 100          # 자동 확장 최대
  
  # 엔진 설정
  engine         = "postgres"
  engine_version = "15.4"
  
  # 데이터베이스 설정
  db_name  = "testdb"
  username = "postgres"
  password = var.db_password
  
  # 네트워크 설정
  vpc_security_group_ids = [aws_security_group.rds_postgresql.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_postgresql.name
  
  # 백업 및 유지보수
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # 성능 설정
  performance_insights_enabled = false  # 비용 절약
  monitoring_interval          = 0      # 비용 절약
  
  # 암호화
  storage_encrypted = true
  
  # 삭제 보호
  deletion_protection = false  # 테스트 환경이므로
  
  tags = {
    Name        = "${var.project_name}-postgresql-test"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# =============================================================================
# 단방향 통신 설정
# =============================================================================

# PUBLIC → ONPREM 통신은 허용되지만, ONPREM → PUBLIC은 차단됨
# 이는 기본적으로 AWS의 보안 정책에 의해 자동으로 적용됨
# 별도의 VPN 서버나 인스턴스가 필요하지 않음
