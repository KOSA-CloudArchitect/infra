# =============================================================================
# EKS Cluster and Managed Node Groups
# =============================================================================

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  count   = var.create_eks_cluster ? 1 : 0

  name               = local.eks_cluster_name
  kubernetes_version = "1.33"

  # EKS 애드온 설정
  addons = {
    coredns = {
      most_recent = true
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      before_compute = true
      resolve_conflicts = "OVERWRITE"
      service_account_role_arn = aws_iam_role.cni_role[0].arn
    }
  }

  # VPC 설정
  vpc_id     = module.vpc_app.vpc_id
  subnet_ids = module.vpc_app.private_subnets  # Private Subnet 사용
  endpoint_public_access                   = true
  endpoint_private_access                  = true


  # EKS Managed Node Groups (새로운 구조)
  eks_managed_node_groups = {
    # Core 노드그룹 - 시스템 애드온, Web/API, 모니터링 코어
    core-on = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.core_on_node_group.instance_types
      min_size       = var.core_on_node_group.min_size
      max_size       = var.core_on_node_group.max_size
      desired_size   = var.core_on_node_group.desired_size
      disk_size      = var.core_on_node_group.disk_size
      capacity_type  = "ON_DEMAND"
      
      labels = {
        capacity-type = "on-demand"
        workload      = "core"
        node-role     = "core"
      }
      
      # CoreDNS가 스케줄링될 수 있도록 테인트 제거
      # taints = {
      #   critical = {
      #     key    = "critical"
      #     value  = "on"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
    }
    
    # Airflow Core 노드그룹 - Scheduler/Webserver
    airflow-core-on = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.airflow_core_on_node_group.instance_types
      min_size       = var.airflow_core_on_node_group.min_size
      max_size       = var.airflow_core_on_node_group.max_size
      desired_size   = var.airflow_core_on_node_group.desired_size
      disk_size      = var.airflow_core_on_node_group.disk_size
      capacity_type  = "ON_DEMAND"
      
      labels = {
        workload      = "airflow-core"
        capacity-type = "on-demand"
      }
      
      # 시스템 파드 스케줄링을 위해 테인트 주석처리
      # taints = {
      #   airflow_core = {
      #     key    = "airflow"
      #     value  = "core"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
    }
    
    # Airflow Worker Spot 노드그룹 - Workers
    airflow-worker-spot = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.airflow_worker_spot_node_group.instance_types
      min_size       = var.airflow_worker_spot_node_group.min_size
      max_size       = var.airflow_worker_spot_node_group.max_size
      desired_size   = var.airflow_worker_spot_node_group.desired_size
      disk_size      = var.airflow_worker_spot_node_group.disk_size
      capacity_type  = "SPOT"
      
      labels = {
        workload      = "airflow-worker"
        capacity-type = "spot"
      }
      
      # Spot 인스턴스는 테인트 없음
    }
    
    # Spark Driver 노드그룹 - Driver
    spark-driver-on = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.spark_driver_on_node_group.instance_types
      min_size       = var.spark_driver_on_node_group.min_size
      max_size       = var.spark_driver_on_node_group.max_size
      desired_size   = var.spark_driver_on_node_group.desired_size
      disk_size      = var.spark_driver_on_node_group.disk_size
      capacity_type  = "ON_DEMAND"
      
      labels = {
        workload      = "spark-driver"
        capacity-type = "on-demand"
      }
      

      # Spark Driver 전용 테인트
      taints = {
        spark_driver = {
          key    = "spark"
          value  = "driver"
          effect = "NO_SCHEDULE"
        }
      }

    }
    
    # Spark Executor Spot 노드그룹 - Executors
    spark-exec-spot = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.spark_exec_spot_node_group.instance_types
      min_size       = var.spark_exec_spot_node_group.min_size
      max_size       = var.spark_exec_spot_node_group.max_size
      desired_size   = var.spark_exec_spot_node_group.desired_size
      disk_size      = var.spark_exec_spot_node_group.disk_size
      capacity_type  = "SPOT"
      
      labels = {
        workload      = "spark-exec"
        capacity-type = "spot"
      }
      

      # Spark Executor 전용 테인트
      taints = {
        spark_executor = {
          key    = "spark"
          value  = "executor"
          effect = "NO_SCHEDULE"
        }
      }

    }
    
    # Kafka Storage 노드그룹 - Kafka 브로커 (기존 storage-on에서 이름 변경)
    kafka-storage-on = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.kafka_storage_on_node_group.instance_types
      min_size       = var.kafka_storage_on_node_group.min_size
      max_size       = var.kafka_storage_on_node_group.max_size
      desired_size   = var.kafka_storage_on_node_group.desired_size
      capacity_type  = "ON_DEMAND"
      
      # EBS 설정 - Kafka 등 스토리지 집약적 워크로드용 최적화
      disk_size      = var.kafka_storage_on_node_group.disk_size
      disk_type      = var.kafka_storage_on_node_group.disk_type
      disk_iops      = var.kafka_storage_on_node_group.disk_iops
      disk_throughput = var.kafka_storage_on_node_group.disk_throughput
      disk_encrypted = var.kafka_storage_on_node_group.disk_encrypted
      
      labels = {
        workload      = "kafka"
        capacity-type = "on-demand"
        storage-type  = "ebs"
      }
      

      # Kafka 전용 테인트
      taints = {
        kafka = {
          key    = "workload"
          value  = "kafka"
          effect = "NO_SCHEDULE"
        }
      }

    }
    
    # GPU Spot 노드그룹 - LLM 추론 (옵션)
    gpu-spot = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.gpu_spot_node_group.instance_types
      min_size       = var.gpu_spot_node_group.min_size
      max_size       = var.gpu_spot_node_group.max_size
      desired_size   = var.gpu_spot_node_group.desired_size
      disk_size      = var.gpu_spot_node_group.disk_size
      capacity_type  = "SPOT"
      
      labels = {
        accel         = "gpu"
        capacity-type = "spot"
      }
      
      # 시스템 파드 스케줄링을 위해 테인트 주석처리
      # taints = {
      #   gpu = {
      #     key    = "accel"
      #     value  = "gpu"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
    }
    
    # LLM 모델 서빙용 고사양 노드그룹
    llm-model-on = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.llm_model_node_group.instance_types
      min_size       = var.llm_model_node_group.min_size
      max_size       = var.llm_model_node_group.max_size
      desired_size   = var.llm_model_node_group.desired_size
      disk_size      = var.llm_model_node_group.disk_size
      capacity_type  = "ON_DEMAND"
      
      labels = {
        workload      = "llm-model"
        capacity-type = "on-demand"
      }
      
      # LLM 모델 전용 테인트
      taints = {
        llm_model = {
          key    = "workload"
          value  = "llm-model"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  # EKS Access Entries (IAM 접근 제어)
  access_entries = merge(
    # Jenkins 역할 (Jenkins가 활성화된 경우에만)
    var.create_jenkins_server ? {
      jenkins = {
        principal_arn = aws_iam_role.jenkins_role[0].arn
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {},
    
    # IAM 사용자들
    {
      # IAM User: kwon -> ClusterAdmin
      user_kwon_admin = {
        principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/kwon"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }

      # IAM User: sunho -> ClusterAdmin
      user_sunho_admin = {
        principal_arn = "arn:aws:iam::914215749228:user/sunho"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }

      # IAM User: tjpark -> ClusterAdmin
      tjpark = {
        principal_arn = "arn:aws:iam::914215749228:user/tjpark"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    }
  )

  # 공통 태그
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# 현재 AWS 계정 정보 조회
data "aws_caller_identity" "current" {}


# =============================================================================
# EBS CSI Driver Helm 차트 설치 (Kubernetes 1.33 호환성)
# =============================================================================

# EBS CSI Driver Helm 차트 설치
resource "helm_release" "ebs_csi_driver" {
  count = var.create_eks_cluster && var.create_k8s_resources ? 1 : 0
  
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.20.0"  # 안정적인 버전 사용
  
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ebs_csi_driver[0].arn
  }
  
  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }
  
  depends_on = [
    module.eks,
    aws_iam_role.ebs_csi_driver
  ]
}

# =============================================================================
# EKS 클러스터 퍼블릭 액세스 CIDR 제한 (현재 IP만 허용)
# =============================================================================

# EKS 클러스터 설정을 업데이트하여 현재 IP만 허용
resource "null_resource" "restrict_eks_public_access" {
  count = var.create_eks_cluster && var.eks_public_access_enabled ? 1 : 0

  triggers = {
    cluster_name = module.eks[0].cluster_name
    current_ip   = chomp(data.http.current_ip.response_body)
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-cluster-config \
        --region ${var.aws_region} \
        --name ${module.eks[0].cluster_name} \
        --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=${chomp(data.http.current_ip.response_body)}/32
    EOT
  }

  depends_on = [module.eks]
}

# =============================================================================
# EKS 클러스터 보안 그룹에 Jenkins 서버 접근 허용
# =============================================================================

# Jenkins 서버에서 EKS API 서버로의 접근을 허용하는 보안 그룹 규칙
resource "aws_security_group_rule" "allow_jenkins_to_eks_api" {
  count = var.create_jenkins_server && var.create_eks_cluster ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_sg[0].id
  security_group_id        = module.eks[0].cluster_security_group_id
  description              = "Allow Jenkins Controller to access EKS API"
}

