# iam.tf

# =============================================================================
# EBS CSI Driver용 IAM 역할
# =============================================================================

# EBS CSI Driver 서비스 어카운트용 IAM 역할
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.create_eks_cluster ? 1 : 0
  
  name = "${var.project_name}-AmazonEKS_EBS_CSI_DriverRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks[0].oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${module.eks[0].oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${module.eks[0].oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-EBS-CSI-Driver-Role"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# EBS CSI Driver 정책 연결
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  count = var.create_eks_cluster ? 1 : 0
  
  role       = aws_iam_role.ebs_csi_driver[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# =============================================================================
# Jenkins EC2 인스턴스용 IAM 역할 ("CEO" 역할)
# =============================================================================

resource "aws_iam_policy" "jenkins_policy" {
  count = var.create_jenkins_server ? 1 : 0
  
  name        = "${var.project_name}-Jenkins-EKS-ECR-Policy"
  description = "Policy for Jenkins to access EKS and ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ],
        Resource = var.create_eks_cluster ? module.eks[0].cluster_arn : "*"
      },
      {
        Effect   = "Allow",
        Action   = ["ecr:*"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "iam:PassRole",
          "iam:GetRole",
          "iam:ListRoles"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "sts:AssumeRole"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "jenkins_role" {
  count = var.create_jenkins_server ? 1 : 0
  
  name               = "${var.project_name}-Jenkins-EKS-ECR-Role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-Jenkins-Role"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_policy_attachment" {
  count = var.create_jenkins_server ? 1 : 0
  
  role       = aws_iam_role.jenkins_role[0].name
  policy_arn = aws_iam_policy.jenkins_policy[0].arn
}

resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  count = var.create_jenkins_server ? 1 : 0
  
  name = "${var.project_name}-Jenkins-Instance-Profile"
  role = aws_iam_role.jenkins_role[0].name

  tags = {
    Name        = "${var.project_name}-Jenkins-Instance-Profile"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# =============================================================================
# EKS CNI 플러그인용 IAM 역할 ("전기 기술자" 역할 - IRSA)
# =============================================================================

resource "aws_iam_role" "cni_role" {
  count = var.create_eks_cluster ? 1 : 0
  
  name = "${var.project_name}-AmazonEKS_CNI_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity",
      Effect = "Allow",
      Principal = {
        Federated = module.eks[0].oidc_provider_arn
      },
      Condition = {
        StringEquals = {
          "${module.eks[0].oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-node"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-AmazonEKS_CNI_Role"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

resource "aws_iam_role_policy_attachment" "cni_policy_attachment" {
  count = var.create_eks_cluster ? 1 : 0
  
  role       = aws_iam_role.cni_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# =============================================================================
# Cluster Autoscaler용 IAM 역할 (주석처리됨)
# =============================================================================

# resource "aws_iam_role" "cluster_autoscaler" {
#   count = var.create_eks_cluster ? 1 : 0
#   
#   name = "${var.project_name}-AmazonEKS_ClusterAutoscalerRole"
#   
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Effect = "Allow"
#         Principal = {
#           Federated = module.eks[0].oidc_provider_arn
#         }
#         Condition = {
#           StringEquals = {
#             "${module.eks[0].oidc_provider}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
#             "${module.eks[0].oidc_provider}:aud" = "sts.amazonaws.com"
#           }
#         }
#       }
#     ]
#   })
#   
#   tags = {
#     Name        = "${var.project_name}-Cluster-Autoscaler-Role"
#     Environment = var.environment
#     Owner       = var.owner
#     CostCenter  = var.cost_center
#   }
# }

# Cluster Autoscaler 정책 (주석처리됨)
# resource "aws_iam_policy" "cluster_autoscaler_policy" {
#   count = var.create_eks_cluster ? 1 : 0
#   
#   name        = "${var.project_name}-ClusterAutoscalerPolicy"
#   description = "Policy for Cluster Autoscaler to manage Auto Scaling Groups"
#   
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "autoscaling:DescribeAutoScalingGroups",
#           "autoscaling:DescribeAutoScalingInstances",
#           "autoscaling:DescribeLaunchConfigurations",
#           "autoscaling:DescribeScalingActivities",
#           "autoscaling:DescribeTags"
#         ]
#         Resource = "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "autoscaling:SetDesiredCapacity",
#           "autoscaling:TerminateInstanceInAutoScalingGroup"
#         ]
#         Resource = "*"
#         Condition = {
#           StringEquals = {
#             "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled" = "true"
#             "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${local.eks_cluster_name}" = "owned"
#           }
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "cluster_autoscaler_policy_attachment" {
#   count = var.create_eks_cluster ? 1 : 0
#   
#   role       = aws_iam_role.cluster_autoscaler[0].name
#   policy_arn = aws_iam_policy.cluster_autoscaler_policy[0].arn
# }