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
  subnet_ids = module.vpc_app.private_subnets 

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    app-nodes = {
      # AL2023은 EKS 1.30+ 에서 기본 AMI 타입
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["c5.2xlarge"]
      min_size     = 1
      max_size     = 3
      desired_size = 1
      
      # AZ-a의 Public Subnet 사용
      #subnet_ids = [module.vpc_app.public_subnets[0]]
      
      # 디스크 크기
      disk_size = 50
    }
  }
  #athentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    jenkins = {
      principal_arn = "arn:aws:iam::890571109462:role/Jenkins-EKS-ECR-Role"

      policy_associations = {
        admin = {
          # 클러스터 전체 관리자 권한
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
      # IAM User: kwon -> ClusterAdmin
    user_kwon_admin = {
      principal_arn = "arn:aws:iam::890571109462:user/kwon"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    # IAM User: sunho -> ClusterAdmin
    user_sunho_admin = {
      principal_arn = "arn:aws:iam::890571109462:user/sunho"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    # IAM User: tjpark -> ClusterAdmin
    tjpark = {
      principal_arn = "arn:aws:iam::890571109462:user/tjpark"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }


# terraform import "module.eks[0].aws_eks_access_entry.this[\"tjpark\"]" "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy,cluster"
  # IAM 역할 및 사용자 매핑은 별도 리소스로 관리

  # 공통 태그
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# =============================================================================
# AWS Auth ConfigMap for IAM Role Mapping
# =============================================================================

# aws-auth ConfigMap 생성 (EKS 클러스터 완전 준비 후)
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = "arn:aws:iam::890571109462:role/Jenkins-EKS-ECR-Role"
        username = "jenkins-ci/cd-admin"
        groups   = ["system:masters"]
      }
    ])
  }

  depends_on = [module.eks]

  # EKS 클러스터가 완전히 준비될 때까지 대기
  provisioner "local-exec" {
    command = "aws eks wait cluster-active --name ${var.eks_cluster_name} --region ap-northeast-2"
  }
}




