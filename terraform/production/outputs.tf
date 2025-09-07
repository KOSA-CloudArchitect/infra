# =============================================================================
# Jenkins 정보
# =============================================================================

output "jenkins_instance_id" {
  description = "Jenkins instance ID"
  value       = var.create_jenkins_server ? aws_instance.jenkins_controller[0].id : null
}

output "jenkins_instance_private_ip" {
  description = "Jenkins instance private IP"
  value       = var.create_jenkins_server ? aws_instance.jenkins_controller[0].private_ip : null
}

output "jenkins_iam_role_arn" {
  description = "Jenkins IAM role ARN"
  value       = var.create_jenkins_server ? aws_iam_role.jenkins_role[0].arn : null
}

output "jenkins_alb_dns_name" {
  description = "Jenkins ALB DNS name"
  value       = var.create_jenkins_server ? aws_lb.jenkins_alb[0].dns_name : null
}

output "jenkins_alb_zone_id" {
  description = "Jenkins ALB zone ID"
  value       = var.create_jenkins_server ? aws_lb.jenkins_alb[0].zone_id : null
}

output "jenkins_access_info" {
  description = "Jenkins access information"
  value = var.create_jenkins_server && length(aws_instance.jenkins_controller) > 0 ? {
    private_ip = aws_instance.jenkins_controller[0].private_ip
    alb_url = "http://${aws_lb.jenkins_alb[0].dns_name}"
    admin_password = "Check terraform.tfvars for jenkins_admin_password"
    web_url = "http://${aws_lb.jenkins_alb[0].dns_name}"
    ssh_command = "ssh -i [key-pair] ec2-user@${aws_instance.jenkins_controller[0].private_ip}"
  } : null
}

# =============================================================================
# 네트워크 및 보안 정보
# =============================================================================

output "current_local_ip" {
  description = "Current local IP address used for EKS public access"
  value       = chomp(data.http.current_ip.response_body)
}

output "eks_public_access_cidrs" {
  description = "EKS public access CIDR blocks"
  value = var.create_eks_cluster ? [
    "${chomp(data.http.current_ip.response_body)}/32"
  ] : null
}

# EBS CSI Driver 정보
output "ebs_csi_driver_role_arn" {
  description = "EBS CSI Driver IAM role ARN"
  value       = var.create_eks_cluster ? aws_iam_role.ebs_csi_driver[0].arn : null
}

# =============================================================================
# EKS 클러스터 정보
# =============================================================================

# EKS 모듈이 생성되지 않을 수 있으므로 조건부로 출력

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.create_eks_cluster ? module.eks[0].cluster_name : null
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
# EKS Security Groups
output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = var.create_eks_cluster ? module.eks[0].cluster_security_group_id : null
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = var.create_eks_cluster ? module.eks[0].node_security_group_id : null
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = var.create_eks_cluster ? module.eks[0].cluster_id : null
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = var.create_eks_cluster ? module.eks[0].cluster_arn : null
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = var.create_eks_cluster ? module.eks[0].cluster_endpoint : null
}

output "eks_cluster_version" {
  description = "EKS cluster version"
  value       = var.create_eks_cluster ? module.eks[0].cluster_version : null
}

output "eks_node_groups" {
  description = "EKS node groups information (new structure)"
  value = var.create_eks_cluster ? {
    core_on = {
      name           = "core-on"
      instance_types = var.core_on_node_group.instance_types
      min_size       = var.core_on_node_group.min_size
      max_size       = var.core_on_node_group.max_size
      desired_size   = var.core_on_node_group.desired_size
      disk_size      = var.core_on_node_group.disk_size
      workload       = "core"
      capacity_type  = "on-demand"
      taints         = []  # 테인트 주석처리됨
      purpose        = "시스템 애드온, Web/API, 모니터링 코어 (테스트용 1개)"
    }
    airflow_core_on = {
      name           = "airflow-core-on"
      instance_types = var.airflow_core_on_node_group.instance_types
      min_size       = var.airflow_core_on_node_group.min_size
      max_size       = var.airflow_core_on_node_group.max_size
      desired_size   = var.airflow_core_on_node_group.desired_size
      disk_size      = var.airflow_core_on_node_group.disk_size
      workload       = "airflow-core"
      capacity_type  = "on-demand"
      taints         = []  # 테인트 주석처리됨
      purpose        = "Airflow Scheduler/Webserver"
    }
    airflow_worker_spot = {
      name           = "airflow-worker-spot"
      instance_types = var.airflow_worker_spot_node_group.instance_types
      min_size       = var.airflow_worker_spot_node_group.min_size
      max_size       = var.airflow_worker_spot_node_group.max_size
      desired_size   = var.airflow_worker_spot_node_group.desired_size
      disk_size      = var.airflow_worker_spot_node_group.disk_size
      workload       = "airflow-worker"
      capacity_type  = "spot"
      taints         = []
      purpose        = "Airflow Workers (포드 밀도↑/비용↓)"
    }
    spark_driver_on = {
      name           = "spark-driver-on"
      instance_types = var.spark_driver_on_node_group.instance_types
      min_size       = var.spark_driver_on_node_group.min_size
      max_size       = var.spark_driver_on_node_group.max_size
      desired_size   = var.spark_driver_on_node_group.desired_size
      disk_size      = var.spark_driver_on_node_group.disk_size
      workload       = "spark-driver"
      capacity_type  = "on-demand"
      taints         = []  # 테인트 주석처리됨
      purpose        = "Spark Driver (드라이버 안정성)"
    }
    spark_exec_spot = {
      name           = "spark-exec-spot"
      instance_types = var.spark_exec_spot_node_group.instance_types
      min_size       = var.spark_exec_spot_node_group.min_size
      max_size       = var.spark_exec_spot_node_group.max_size
      desired_size   = var.spark_exec_spot_node_group.desired_size
      disk_size      = var.spark_exec_spot_node_group.disk_size
      workload       = "spark-exec"
      capacity_type  = "spot"
      taints         = []
      purpose        = "Spark Executors (포드 수 확장·스팟)"
    }
    kafka_storage_on = {
      name           = "kafka-storage-on"
      instance_types = var.kafka_storage_on_node_group.instance_types
      min_size       = var.kafka_storage_on_node_group.min_size
      max_size       = var.kafka_storage_on_node_group.max_size
      desired_size   = var.kafka_storage_on_node_group.desired_size
      disk_size      = var.kafka_storage_on_node_group.disk_size
      disk_type      = var.kafka_storage_on_node_group.disk_type
      disk_iops      = var.kafka_storage_on_node_group.disk_iops
      disk_throughput = var.kafka_storage_on_node_group.disk_throughput
      workload       = "kafka"
      capacity_type  = "on-demand"
      taints         = []  # 테인트 주석처리됨
      purpose        = "Kafka 브로커 (상태/디스크 분리, 테스트용 1개)"
    }
    gpu_spot = {
      name           = "gpu-spot"
      instance_types = var.gpu_spot_node_group.instance_types
      min_size       = var.gpu_spot_node_group.min_size
      max_size       = var.gpu_spot_node_group.max_size
      desired_size   = var.gpu_spot_node_group.desired_size
      disk_size      = var.gpu_spot_node_group.disk_size
      workload       = "gpu"
      capacity_type  = "spot"
      taints         = []  # 테인트 주석처리됨
      purpose        = "LLM 추론 (필요 시에만)"
    }
  } : null
}

output "eks_cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = var.create_eks_cluster ? module.eks[0].cluster_oidc_issuer_url : null
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = var.create_eks_cluster ? module.eks[0].cluster_certificate_authority_data : null
}

# EKS Node Groups
output "eks_nodegroup_ids" {
  description = "EKS managed node group IDs"
  value       = var.create_eks_cluster ? module.eks[0].eks_managed_node_groups_autoscaling_group_names : null
}

# =============================================================================
# VPC 출력
# =============================================================================

output "vpc_app_id" {
  description = "VPC-APP ID"
  value       = module.vpc_app.vpc_id
}

output "vpc_db_id" {
  description = "VPC-DB ID"
  value       = module.vpc_db.vpc_id
}

output "vpc_app_cidr" {
  description = "VPC-APP CIDR"
  value       = module.vpc_app.vpc_cidr_block
}

output "vpc_db_cidr" {
  description = "VPC-DB CIDR"
  value       = module.vpc_db.vpc_cidr_block
}

# =============================================================================
# Subnet 출력
# =============================================================================

output "vpc_app_public_subnets" {
  description = "VPC-APP Public Subnets"
  value       = module.vpc_app.public_subnets
}

output "vpc_app_private_subnets" {
  description = "VPC-APP Private Subnets"
  value       = module.vpc_app.private_subnets
}

output "vpc_db_private_subnets" {
  description = "VPC-DB Private Subnets"
  value       = module.vpc_db.private_subnets
}

# =============================================================================
# VPC Peering 출력
# =============================================================================

output "vpc_peering_connection_id" {
  description = "VPC Peering Connection ID"
  value       = aws_vpc_peering_connection.app_to_db.id
}

# =============================================================================
# 단방향 통신 정보
# =============================================================================

output "communication_direction" {
  description = "Communication direction information"
  value = {
    public_to_onprem = "Allowed"
    onprem_to_public = "Blocked"
    vpn_enabled = var.create_vpn_connection ? "Yes" : "No"
    note = var.create_vpn_connection ? "Site-to-Site VPN configured" : "No VPN server required for this setup"
  }
}

# =============================================================================
# VPN 정보
# =============================================================================

output "vpn_gateway_id" {
  description = "VPN Gateway ID"
  value       = var.create_vpn_connection ? aws_vpn_gateway.aws_vgw[0].id : null
}

output "customer_gateway_id" {
  description = "Customer Gateway ID"
  value       = var.create_vpn_connection ? aws_customer_gateway.onprem_cgw[0].id : null
}

output "vpn_connection_id" {
  description = "VPN Connection ID"
  value       = var.create_vpn_connection ? aws_vpn_connection.aws_to_onprem[0].id : null
}

output "vpn_connection_tunnel1_address" {
  description = "VPN Connection Tunnel 1 Address"
  value       = var.create_vpn_connection ? aws_vpn_connection.aws_to_onprem[0].tunnel1_address : null
}

output "vpn_connection_tunnel2_address" {
  description = "VPN Connection Tunnel 2 Address"
  value       = var.create_vpn_connection ? aws_vpn_connection.aws_to_onprem[0].tunnel2_address : null
}

output "vpn_connection_tunnel1_preshared_key" {
  description = "VPN Connection Tunnel 1 Preshared Key"
  value       = var.create_vpn_connection ? aws_vpn_connection.aws_to_onprem[0].tunnel1_preshared_key : null
  sensitive   = true
}

output "vpn_connection_tunnel2_preshared_key" {
  description = "VPN Connection Tunnel 2 Preshared Key"
  value       = var.create_vpn_connection ? aws_vpn_connection.aws_to_onprem[0].tunnel2_preshared_key : null
  sensitive   = true
}

output "vpn_setup_info" {
  description = "VPN setup information for on-premises configuration"
  value = var.create_vpn_connection ? {
    aws_tunnel1_ip = aws_vpn_connection.aws_to_onprem[0].tunnel1_address
    aws_tunnel2_ip = aws_vpn_connection.aws_to_onprem[0].tunnel2_address
    tunnel1_preshared_key = "Check terraform output vpn_connection_tunnel1_preshared_key"
    tunnel2_preshared_key = "Check terraform output vpn_connection_tunnel2_preshared_key"
    onprem_cidr = var.onprem_cidr
    aws_cidr = var.vpc_app_cidr
    note = "Configure on-premises router with these tunnel IPs and preshared keys"
  } : null
}

output "onprem_network_info" {
  description = "On-premises network information"
  value = {
    cidr = var.onprem_cidr
    note = "This network can receive traffic from AWS but cannot initiate connections to AWS"
  }
}

# =============================================================================
# RDS 데이터베이스 정보
# =============================================================================

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = var.create_rds ? aws_db_instance.airflow_db[0].id : null
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = var.create_rds ? aws_db_instance.airflow_db[0].endpoint : null
}

output "rds_port" {
  description = "RDS instance port"
  value       = var.create_rds ? aws_db_instance.airflow_db[0].port : null
}

output "rds_database_name" {
  description = "RDS database name"
  value       = var.create_rds ? aws_db_instance.airflow_db[0].db_name : null
}

output "rds_username" {
  description = "RDS master username"
  value       = var.create_rds ? aws_db_instance.airflow_db[0].username : null
}

output "rds_connection_info" {
  description = "RDS connection information for Airflow"
  value = var.create_rds ? {
    host = aws_db_instance.airflow_db[0].endpoint
    port = aws_db_instance.airflow_db[0].port
    database = aws_db_instance.airflow_db[0].db_name
    username = aws_db_instance.airflow_db[0].username
    password = "Check terraform.tfvars for rds_master_password"
    connection_string = "postgresql://${aws_db_instance.airflow_db[0].username}:<password>@${aws_db_instance.airflow_db[0].endpoint}:${aws_db_instance.airflow_db[0].port}/${aws_db_instance.airflow_db[0].db_name}"
    note = "Use this connection info in Airflow configuration"
  } : null
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = var.create_rds ? aws_security_group.rds_sg[0].id : null
}

output "rds_subnet_group_name" {
  description = "RDS subnet group name"
  value       = var.create_rds ? aws_db_subnet_group.rds_subnet_group[0].name : null
}

# =============================================================================
# S3 버킷 정보
# =============================================================================

output "airflow_logs_bucket_name" {
  description = "Airflow logs S3 bucket name"
  value       = var.create_s3_buckets ? aws_s3_bucket.airflow_logs[0].bucket : null
}

output "airflow_logs_bucket_arn" {
  description = "Airflow logs S3 bucket ARN"
  value       = var.create_s3_buckets ? aws_s3_bucket.airflow_logs[0].arn : null
}

output "spark_checkpoints_bucket_name" {
  description = "Spark checkpoints S3 bucket name"
  value       = var.create_s3_buckets ? aws_s3_bucket.spark_checkpoints[0].bucket : null
}

output "spark_checkpoints_bucket_arn" {
  description = "Spark checkpoints S3 bucket ARN"
  value       = var.create_s3_buckets ? aws_s3_bucket.spark_checkpoints[0].arn : null
}

output "s3_buckets_info" {
  description = "S3 buckets information for Airflow and Spark"
  value = var.create_s3_buckets ? {
    airflow_logs = {
      bucket_name = aws_s3_bucket.airflow_logs[0].bucket
      bucket_arn = aws_s3_bucket.airflow_logs[0].arn
      s3_url = "s3://${aws_s3_bucket.airflow_logs[0].bucket}/log"
      purpose = "Airflow logs storage"
    }
    spark_checkpoints = {
      bucket_name = aws_s3_bucket.spark_checkpoints[0].bucket
      bucket_arn = aws_s3_bucket.spark_checkpoints[0].arn
      s3_url = "s3://${aws_s3_bucket.spark_checkpoints[0].bucket}/checkpoints"
      purpose = "Spark streaming checkpoints"
    }
  } : null
}

# =============================================================================
# IRSA 서비스 어카운트 정보
# =============================================================================

output "airflow_irsa_role_arn" {
  description = "Airflow IRSA role ARN"
  value       = var.create_s3_buckets ? aws_iam_role.airflow_irsa[0].arn : null
}

output "spark_irsa_role_arn" {
  description = "Spark IRSA role ARN"
  value       = var.create_s3_buckets ? aws_iam_role.spark_irsa[0].arn : null
}

output "irsa_service_accounts_info" {
  description = "IRSA service accounts information"
  value = var.create_s3_buckets ? {
    airflow_irsa = {
      role_arn = aws_iam_role.airflow_irsa[0].arn
      service_account_name = "airflow-irsa"
      namespace = "airflow"
      purpose = "Airflow S3 access for logs"
      permissions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      k8s_resource_created = var.create_k8s_resources
    }
    spark_irsa = {
      role_arn = aws_iam_role.spark_irsa[0].arn
      service_account_name = "spark-irsa"
      namespace = "spark"
      purpose = "Spark S3 access for checkpoints"
      permissions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      k8s_resource_created = var.create_k8s_resources
    }
  } : null
}

# =============================================================================
# 비용 최적화 정보
# =============================================================================

output "cost_optimization_info" {
  description = "Cost Optimization Information"
  value = {
    vpc_count = 2
    nat_gateway_count = 1
    eks_cluster = var.create_eks_cluster ? "Enabled" : "Disabled"
    eks_node_groups = var.create_eks_cluster ? {
      core_on = "c7g.medium (1-3 nodes, 테스트용 1개 시작)"
      airflow_core_on = "c7g.medium (1-3 nodes, On-Demand)"
      airflow_worker_spot = "c7g.medium/m7g.medium (0-20 nodes, Spot)"
      spark_driver_on = "m7g.large (1-2 nodes, On-Demand)"
      spark_exec_spot = "c7g.large/r7g.large (0-50 nodes, Spot)"
      kafka_storage_on = "c7g.large/m7g.large (1-3 nodes, 300GB EBS, 테스트용 1개 시작)"
      gpu_spot = "g5.xlarge/g6.xlarge (0-6 nodes, Spot)"
    } : null
    jenkins_server = var.create_jenkins_server ? "Enabled" : "Disabled"
    jenkins_instance_type = var.create_jenkins_server ? var.jenkins_instance_type : null
    jenkins_alb = var.create_jenkins_server ? "Enabled" : "Disabled"
    rds_database = var.create_rds ? "Enabled" : "Disabled"
    rds_instance_type = var.create_rds ? var.rds_instance_class : null
    rds_storage = var.create_rds ? "${var.rds_allocated_storage}GB (max ${var.rds_max_allocated_storage}GB)" : null
    rds_multi_az = var.create_rds ? var.rds_multi_az : null
    s3_buckets = var.create_s3_buckets ? "Enabled" : "Disabled"
    s3_bucket_count = var.create_s3_buckets ? 2 : 0
    s3_purpose = var.create_s3_buckets ? "Airflow logs + Spark checkpoints" : null
    irsa_service_accounts = var.create_s3_buckets ? 2 : 0
    vpn_server = "Not required - AWS default security policy"
    note = "Multi-workload EKS cluster with specialized node groups - On-Demand for critical workloads, Spot for scalable workloads"
  }
}
