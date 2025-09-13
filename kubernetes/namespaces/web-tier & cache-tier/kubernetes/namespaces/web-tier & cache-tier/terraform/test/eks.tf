# =============================================================================
# EKS Cluster and Managed Node Groups for Test Environment
# =============================================================================

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "hihypipe-test-eks"
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
      instance_types = ["t3.medium"]  # Test 환경용으로 t3.medium 사용
      min_size     = 1
      max_size     = 3
      desired_size = 1
      
      # 디스크 크기
      disk_size = 20  # Test 환경용으로 20GB 사용
      
      # 태그 설정
      labels = {
        Environment = "test"
        NodeGroup   = "app-nodes"
      }
    }
  }

  # EKS Access Entries (IAM 접근 제어)
  access_entries = {
    # Jenkins 역할
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

  # 공통 태그
  tags = {
    Environment = "test"
    Project     = "hihypipe"
    Purpose     = "EKS-Test-Cluster"
  }
}

# =============================================================================
# AWS Load Balancer Controller IAM Role
# =============================================================================

# AWS Load Balancer Controller용 IAM 역할
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AmazonEKSLoadBalancerControllerRole-Test"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.oidc_provider, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "aws-load-balancer-controller-role-test"
    Environment = "test"
    Project     = "hihypipe"
  }
}

# AWS Load Balancer Controller 정책 연결
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
}

# =============================================================================
# Bastion EC2 Instance for EKS Access
# =============================================================================

# Bastion용 보안 그룹
resource "aws_security_group" "bastion" {
  name_prefix = "bastion-sg-test-"
  vpc_id      = module.vpc_app.vpc_id

  # SSH 접근 허용 (22번 포트)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # EKS 클러스터로의 접근 허용
  ingress {
    description = "Access to EKS cluster"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc_app.vpc_cidr_block]
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "bastion-security-group-test"
    Environment = "test"
    Project     = "hihypipe"
    Purpose     = "Bastion-Host"
  }
}

# Bastion용 키 페어
resource "aws_key_pair" "bastion" {
  key_name   = "bastion-key-pair-test"
  public_key = file("${path.module}/bastion-key.pub")
}

# Bastion EC2 인스턴스
resource "aws_instance" "bastion" {
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2023 (ap-northeast-2)
  instance_type          = "t3.micro"
  key_name              = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = module.vpc_app.public_subnets[0]  # 첫 번째 public subnet

  # 사용자 데이터로 필요한 도구 설치
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git jq
              systemctl start docker
              systemctl enable docker
              
              # kubectl 설치
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/
              
              # AWS CLI v2 설치
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install
              
              # Helm 설치
              curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              
              # EKS 도구 설치
              curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
              chmod +x aws-iam-authenticator
              mv aws-iam-authenticator /usr/local/bin/
              
              # 사용자 생성 (선택사항)
              useradd -m -s /bin/bash eks-user
              usermod -aG docker eks-user
              echo "eks-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
              
              # SSH 키 설정
              mkdir -p /home/eks-user/.ssh
              chown eks-user:eks-user /home/eks-user/.ssh
              chmod 700 /home/eks-user/.ssh
              EOF

  tags = {
    Name        = "bastion-host-test"
    Environment = "test"
    Project     = "hihypipe"
    Purpose     = "EKS-Access"
  }

  depends_on = [module.vpc_app]
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# =============================================================================
# Outputs
# =============================================================================

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc_app.vpc_id
}

output "private_subnets" {
  description = "Private subnets"
  value       = module.vpc_app.private_subnets
}

output "public_subnets" {
  description = "Public subnets"
  value       = module.vpc_app.public_subnets
}

output "kubeconfig_command" {
  description = "Command to configure kubeconfig"
  value       = "aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-test-eks"
}

output "bastion_public_ip" {
  description = "Public IP of Bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to Bastion"
  value       = "ssh -i bastion-key.pem ec2-user@${aws_instance.bastion.public_ip}"
}

output "bastion_eks_access_command" {
  description = "Command to access EKS from Bastion"
  value       = "ssh -i bastion-key.pem ec2-user@${aws_instance.bastion.public_ip} 'aws eks update-kubeconfig --region ap-northeast-2 --name hihypipe-test-eks'"
}
