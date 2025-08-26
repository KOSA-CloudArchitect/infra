# =============================================================================
# EKS Cluster and Managed Node Groups
# =============================================================================

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  count   = var.create_eks_cluster ? 1 : 0

  name               = var.eks_cluster_name
  kubernetes_version = "1.33"

  # EKS 애드온 설정
  addons = {
    coredns = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # VPC 설정
  vpc_id     = module.vpc_app.vpc_id
  subnet_ids = module.vpc_app.private_subnets  # Public Subnet 사용

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    app-nodes = {
      # AL2023은 EKS 1.30+ 에서 기본 AMI 타입
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size     = 1
      max_size     = 3
      desired_size = 1
      
      # AZ-a의 Public Subnet 사용
      #subnet_ids = [module.vpc_app.public_subnets[0]]
      
      # 디스크 크기
      disk_size = 20
    }
  }

  # 공통 태그
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}




