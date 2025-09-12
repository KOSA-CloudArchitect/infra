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
  description = "Environment name (e.g., dev, test, staging, production)"
  type        = string
  default     = "production"
}

# Environment Suffix (for naming)
variable "environment_suffix" {
  description = "Environment suffix for resource naming (e.g., -dev, -test, -staging, -prod)"
  type        = string
  default     = ""
}

# Resource Naming Prefix
variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "hihypipe"
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
# Jenkins 설정
# =============================================================================

# Jenkins 서버 생성 여부
variable "create_jenkins_server" {
  description = "Whether to create Jenkins server"
  type        = bool
  default     = true
}

# Jenkins IAM 역할 생성 여부
variable "create_jenkins_role" {
  description = "Whether to create Jenkins IAM role"
  type        = bool
  default     = true
}

# Jenkins AMI ID
variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins server"
  type        = string
  default     = "ami-068d7b3dd93d9c2a6"  # Amazon Linux 2023 AMI (ap-northeast-2)
}

# Jenkins 인스턴스 타입
variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
}

# Jenkins 키페어 이름
variable "jenkins_key_pair_name" {
  description = "Key pair name for Jenkins server"
  type        = string
  default     = "jenkins"
}

# Jenkins 관리자 비밀번호
variable "jenkins_admin_password" {
  description = "Admin password for Jenkins"
  type        = string
  sensitive   = true
  default     = "admin123!"
}

# Jenkins 볼륨 크기
variable "jenkins_volume_size" {
  description = "Volume size for Jenkins server"
  type        = number
  default     = 30
}

# =============================================================================
# EKS 설정
# =============================================================================

# EKS Cluster Creation Flag
variable "create_eks_cluster" {
  description = "Whether to create EKS cluster"
  type        = bool
  default     = true
}

# EKS Cluster Configuration
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = ""
}

# =============================================================================
# EKS 노드그룹 설정 (새로운 구조)
# =============================================================================

# Core 노드그룹 - 시스템 애드온, Web/API, 모니터링 코어
variable "core_on_node_group" {
  description = "Core node group for system addons, web/api, monitoring"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["c6g.large"]
    min_size       = 3  # 기본 3개
    max_size       = 5  # 최대 5개까지 확장 가능
    desired_size   = 3  # 기본 3개
    disk_size      = 20
  }
}

# Airflow Core 노드그룹 - Scheduler/Webserver
variable "airflow_core_on_node_group" {
  description = "Airflow core node group for scheduler and webserver"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["c7g.medium"]
    min_size       = 0
    max_size       = 3
    desired_size   = 0
    disk_size      = 20
  }
}

# Airflow Worker Spot 노드그룹 - Workers
variable "airflow_worker_spot_node_group" {
  description = "Airflow worker spot node group for workers"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["c7g.medium", "m7g.medium"]
    min_size       = 0
    max_size       = 20
    desired_size   = 0
    disk_size      = 20
  }
}

# Spark Driver 노드그룹 - Driver
variable "spark_driver_on_node_group" {
  description = "Spark driver node group for drivers"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["m7g.large"]
    min_size       = 0
    max_size       = 2
    desired_size   = 0
    disk_size      = 20
  }
}

# Spark Executor Spot 노드그룹 - Executors
variable "spark_exec_spot_node_group" {
  description = "Spark executor spot node group for executors"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["c7g.large", "r7g.large"]
    min_size       = 0
    max_size       = 50
    desired_size   = 0
    disk_size      = 20
  }
}

# Kafka Storage 노드그룹 - Kafka 브로커
variable "kafka_storage_on_node_group" {
  description = "Kafka storage node group for Kafka brokers"
  type = object({
    instance_types   = list(string)
    min_size         = number
    max_size         = number
    desired_size     = number
    disk_size        = number
    disk_type        = string
    disk_iops        = number
    disk_throughput  = number
    disk_encrypted   = bool
  })
  default = {
    instance_types   = ["c7g.large", "m7g.large"]  # i4g.large 대신 m7g.large 사용
    min_size         = 2  # 기본 2개
    max_size         = 3  # 최대 3개까지 확장 가능
    desired_size     = 2  # 기본 2개
    disk_size        = 300
    disk_type        = "gp3"
    disk_iops        = 3000
    disk_throughput  = 125
    disk_encrypted   = true
  }
}

# GPU Spot 노드그룹 - LLM 추론 (옵션)
variable "gpu_spot_node_group" {
  description = "GPU spot node group for LLM inference"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["g5.xlarge", "g6.xlarge"]
    min_size       = 0
    max_size       = 6
    desired_size   = 0
    disk_size      = 20
  }
}

# LLM 모델 서빙용 고사양 노드그룹
variable "llm_model_node_group" {
  description = "High-spec node group for LLM model serving"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["t4g.medium"]
    min_size       = 0
    max_size       = 3
    desired_size   = 1
    disk_size      = 20
  }
}

# 베스천 호스트 접근용 IP 주소
variable "my_ip_for_bastion" {
  description = "Your IP address for bastion host access"
  type        = string
  default     = "0.0.0.0/32"
}

# GPU 노드그룹 - AWS GPU 인스턴스 제한으로 인해 주석처리
# 필요시 AWS Support에 GPU 인스턴스 제한 해제 요청 후 활성화
# variable "gpu_node_group" {
#   description = "GPU node group configuration"
#   type = object({
#     instance_types = list(string)
#     min_size       = number
#     max_size       = number
#     desired_size   = number
#     disk_size      = number
#     capacity_type  = string
#   })
#   default = {
#     instance_types = ["g5.xlarge", "g6.xlarge"]
#     min_size       = 0
#     max_size       = 6
#     desired_size   = 0
#     disk_size      = 20
#     capacity_type  = "SPOT"
#   }
# }

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
  default     = "172.21.0.0/16"
}

variable "vpc_app_cidr" {
  description = "CIDR block for VPC-APP"
  type        = string
  default     = "172.20.0.0/16"
}

# VPC-DB Private Subnets
variable "vpc_db_private_subnets" {
  description = "Private subnets for VPC-DB"
  type        = list(string)
  default     = [
    "172.21.0.0/20",    # Private-DB AZ-a
    "172.21.16.0/20",   # Private-DB AZ-b
    "172.21.32.0/20"   # Private-DB AZ-c
  ]
}

# VPC-APP Public Subnets
variable "vpc_app_public_subnets" {
  description = "Public subnets for VPC-APP"
  type        = list(string)
  default     = [
    "172.20.0.0/20",    # Public AZ-a
    "172.20.16.0/20",   # Public AZ-b
    "172.20.32.0/20"   # Public AZ-c
  ]
}

# VPC-APP Private Subnets
variable "vpc_app_private_subnets" {
  description = "Private subnets for VPC-APP"
  type        = list(string)
  default     = [
    "172.20.48.0/20",   # Private AZ-a
    "172.20.64.0/20",   # Private AZ-b
    "172.20.80.0/20"   # Private AZ-c
  ]
}

# NAT/VPN 비용 제어 플래그
variable "enable_nat_gateway" {
  description = "Enable NAT gateway for VPC-APP (costly resource)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway instead of one per AZ"
  type        = bool
  default     = true
}

# =============================================================================
# On-premises 설정
# =============================================================================

# =============================================================================
# VPN 설정
# =============================================================================

variable "create_vpn_connection" {
  description = "Whether to create VPN connection to on-premises"
  type        = bool
  default     = true
}

variable "onprem_public_ip" {
  description = "On-premises public IP address for VPN connection"
  type        = string
  default     = "112.221.225.163"
}

variable "onprem_bgp_asn" {
  description = "On-premises BGP ASN for VPN connection"
  type        = number
  default     = 65000
}

# On-premises CIDR
variable "onprem_cidr" {
  description = "On-premises network CIDR"
  type        = string
  default     = "10.128.0.0/19"
}

# =============================================================================
# RDS 데이터베이스 설정
# =============================================================================

# RDS 생성 여부
variable "create_rds" {
  description = "Whether to create RDS database"
  type        = bool
  default     = true
}

# RDS 엔진 타입
variable "rds_engine" {
  description = "RDS engine type"
  type        = string
  default     = "postgres"
}

# RDS 엔진 버전
variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "17.6"  # PostgreSQL 15.4 대신 15.3 사용
}

# RDS 인스턴스 클래스
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"  # 테스트 환경용 작은 인스턴스
}

# RDS 할당 스토리지
variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

# RDS 최대 할당 스토리지 (자동 스케일링)
variable "rds_max_allocated_storage" {
  description = "RDS max allocated storage for autoscaling"
  type        = number
  default     = 100
}

# RDS 데이터베이스 이름
variable "rds_database_name" {
  description = "RDS database name"
  type        = string
  default     = "airflow"
}

# RDS 마스터 사용자명
variable "rds_master_username" {
  description = "RDS master username"
  type        = string
  default     = "airflow"
}

# RDS 마스터 비밀번호
variable "rds_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = "airflow123!"
}

# RDS 백업 보존 기간
variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

# RDS 백업 윈도우
variable "rds_backup_window" {
  description = "RDS backup window"
  type        = string
  default     = "03:00-04:00"
}

# RDS 유지보수 윈도우
variable "rds_maintenance_window" {
  description = "RDS maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# RDS 멀티 AZ 배포
variable "rds_multi_az" {
  description = "RDS multi-AZ deployment"
  type        = bool
  default     = false  # 테스트 환경에서는 비용 절약을 위해 false
}

# RDS 스토리지 암호화
variable "rds_storage_encrypted" {
  description = "RDS storage encryption"
  type        = bool
  default     = true
}

# RDS 삭제 보호
variable "rds_deletion_protection" {
  description = "RDS deletion protection"
  type        = bool
  default     = false  # 테스트 환경에서는 false
}

# RDS 스킵 최종 스냅샷
variable "rds_skip_final_snapshot" {
  description = "RDS skip final snapshot"
  type        = bool
  default     = true  # 테스트 환경에서는 true
}

# =============================================================================
# S3 버킷 설정
# =============================================================================

# S3 버킷 생성 여부
variable "create_s3_buckets" {
  description = "Whether to create S3 buckets for Airflow logs and Spark checkpoints"
  type        = bool
  default     = true
}

# Airflow 로그용 S3 버킷 이름
variable "airflow_logs_bucket_name" {
  description = "S3 bucket name for Airflow logs"
  type        = string
  default     = "hihypipe-airflow-logs"
}

# Spark 체크포인트용 S3 버킷 이름
variable "spark_checkpoints_bucket_name" {
  description = "S3 bucket name for Spark checkpoints"
  type        = string
  default     = "hihypipe-spark-checkpoints"
}

# S3 버킷 버전 관리
variable "s3_bucket_versioning" {
  description = "S3 bucket versioning"
  type        = bool
  default     = true
}

# S3 버킷 암호화
variable "s3_bucket_encryption" {
  description = "S3 bucket encryption"
  type        = bool
  default     = true
}

# S3 버킷 생명주기 정책 (로그 정리)
variable "s3_lifecycle_enabled" {
  description = "Enable S3 lifecycle policy for log cleanup"
  type        = bool
  default     = true
}

# S3 로그 보존 기간 (일)
variable "s3_log_retention_days" {
  description = "S3 log retention period in days"
  type        = number
  default     = 30
}

# =============================================================================
# Kubernetes 리소스 설정
# =============================================================================

# Kubernetes 리소스 생성 여부
variable "create_k8s_resources" {
  description = "Whether to create Kubernetes resources (namespaces, service accounts)"
  type        = bool
  default     = false  # 기본적으로 비활성화 (EKS 클러스터 생성 후 별도 배포)
}

# =============================================================================
# EKS 보안 설정
# =============================================================================

# EKS 퍼블릭 액세스 허용 여부
variable "eks_public_access_enabled" {
  description = "Whether to enable public access to EKS cluster endpoint"
  type        = bool
  default     = true
}

# 추가 IP CIDR 블록 (현재 IP 외에 추가로 허용할 IP들)
variable "eks_additional_public_access_cidrs" {
  description = "Additional CIDR blocks for EKS public access (besides current IP)"
  type        = list(string)
  default     = []  # 현재 IP만 허용 (보안 강화)
}

# 모든 IP 허용 여부 (보안상 권장하지 않음)
variable "eks_allow_all_ips" {
  description = "Whether to allow all IPs (0.0.0.0/0) - NOT RECOMMENDED for production"
  type        = bool
  default     = false  # 보안을 위해 현재 IP만 허용
}
