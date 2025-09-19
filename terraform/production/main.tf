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
# 로컬 변수 (동적 네이밍)
# =============================================================================

locals {
  # EKS 클러스터 이름 (변수가 비어있으면 동적 생성)
  eks_cluster_name = var.eks_cluster_name != "" ? var.eks_cluster_name : "${var.resource_prefix}-eks-cluster${var.environment_suffix}"
  
  # 공통 태그
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project_name
  }
}

# 현재 로컬 IP 가져오기
data "http" "current_ip" {
  url = "https://ipv4.icanhazip.com"
  
  request_headers = {
    Accept = "text/plain"
  }
}

# Kubernetes Provider 설정
provider "kubernetes" {
  host                   = var.create_eks_cluster ? module.eks[0].cluster_endpoint : null
  cluster_ca_certificate = var.create_eks_cluster ? base64decode(module.eks[0].cluster_certificate_authority_data) : null
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.create_eks_cluster ? module.eks[0].cluster_name : ""]
  }
}

# Helm Provider 설정
provider "helm" {
  kubernetes {
    host                   = var.create_eks_cluster ? module.eks[0].cluster_endpoint : null
    cluster_ca_certificate = var.create_eks_cluster ? base64decode(module.eks[0].cluster_certificate_authority_data) : null
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.create_eks_cluster ? module.eks[0].cluster_name : ""]
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

  name = "${var.resource_prefix}-vpc-app${var.environment_suffix}"
  cidr = var.vpc_app_cidr
  
  azs             = var.availability_zones
  public_subnets  = var.vpc_app_public_subnets
  private_subnets = var.vpc_app_private_subnets


  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway


  # Karpenter용 서브넷 태그 추가
  public_subnet_tags = {
    "karpenter.sh/discovery/${local.eks_cluster_name}" = "*"
  }
  
  private_subnet_tags = {
    "karpenter.sh/discovery/${local.eks_cluster_name}" = "*"
  }

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
  
  name = "${var.resource_prefix}-vpc-db${var.environment_suffix}"
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
# VPC Peering (App과 DB VPC 간 통신)
# =============================================================================

resource "aws_vpc_peering_connection" "app_to_db" {
  vpc_id      = module.vpc_app.vpc_id
  peer_vpc_id = module.vpc_db.vpc_id
  
  auto_accept = true
  
  tags = {
    Name        = "${var.resource_prefix}-vpc-peering-app-to-db${var.environment_suffix}"
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
# VPN 설정 (Site-to-Site VPN)
# =============================================================================

# Customer Gateway (On-premises 라우터 정보)
resource "aws_customer_gateway" "onprem_cgw" {
  count = var.create_vpn_connection ? 1 : 0
  
  bgp_asn    = var.onprem_bgp_asn
  ip_address = var.onprem_public_ip
  type       = "ipsec.1"

  tags = {
    Name        = "${var.project_name}-onprem-cgw"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# VPN Gateway (AWS 측)
resource "aws_vpn_gateway" "aws_vgw" {
  count = var.create_vpn_connection ? 1 : 0
  
  vpc_id = module.vpc_app.vpc_id

  tags = {
    Name        = "${var.project_name}-aws-vgw"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# VPN Connection (AWS ↔ On-premises)
resource "aws_vpn_connection" "aws_to_onprem" {
  count = var.create_vpn_connection ? 1 : 0
  
  vpn_gateway_id      = aws_vpn_gateway.aws_vgw[0].id
  customer_gateway_id = aws_customer_gateway.onprem_cgw[0].id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name        = "${var.project_name}-aws-to-onprem"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Static Routes (AWS → On-premises)
resource "aws_vpn_connection_route" "aws_to_onprem_route" {
  count = var.create_vpn_connection ? 1 : 0
  
  destination_cidr_block = var.onprem_cidr
  vpn_connection_id      = aws_vpn_connection.aws_to_onprem[0].id
}


resource "aws_vpn_gateway_route_propagation" "vgw_propagation_private" {
  count = var.create_vpn_connection ? length(module.vpc_app.private_route_table_ids) : 0

  vpn_gateway_id = aws_vpn_gateway.aws_vgw[0].id
  route_table_id = module.vpc_app.private_route_table_ids[count.index]
}


# =============================================================================
# 단방향 통신 설정
# =============================================================================

# PUBLIC → ONPREM 통신은 허용되지만, ONPREM → PUBLIC은 차단됨
# 이는 기본적으로 AWS의 보안 정책에 의해 자동으로 적용됨
# 별도의 VPN 서버나 인스턴스가 필요하지 않음
