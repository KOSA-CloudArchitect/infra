# =============================================================================
# Redshift Serverless for Data Warehouse
# =============================================================================

# Redshift Serverless Namespace
resource "aws_redshiftserverless_namespace" "main" {
  count = var.create_redshift ? 1 : 0
  
  namespace_name = "${var.project_name}-redshift-namespace"
  
  # 기본 데이터베이스 및 관리자 사용자 설정
  db_name        = var.redshift_database_name
  # admin_username/admin_password는 provider 지원 제한으로 생략 (둘 다 미지정)
  
  # IAM Role 설정
  iam_roles = [aws_iam_role.redshift_s3_copy_role[0].arn]
  
  # 암호화 설정
  #kms_key_id = var.redshift_kms_key_id
  
  # 로깅 설정 (CloudWatch 비활성화)
  # log_exports = ["userlog", "connectionlog", "useractivitylog"]
  
  tags = {
    Name        = "${var.project_name}-redshift-namespace"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Purpose     = "Data Warehouse for Analytics"
  }
}

# Redshift Serverless Workgroup
resource "aws_redshiftserverless_workgroup" "main" {
  count = var.create_redshift ? 1 : 0
  
  workgroup_name = "${var.project_name}-redshift-workgroup"
  namespace_name = aws_redshiftserverless_namespace.main[0].namespace_name
  
  # 컴퓨팅 설정
  base_capacity = var.redshift_serverless_base_capacity
  max_capacity  = var.redshift_serverless_max_capacity
  
  # 보안 설정
  publicly_accessible = false
  
  # 네트워크 설정 (VPC-DB 사용)
  subnet_ids         = module.vpc_db.private_subnets
  security_group_ids = [aws_security_group.redshift_sg[0].id]
  
  tags = {
    Name        = "${var.project_name}-redshift-workgroup"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Purpose     = "Data Warehouse for Analytics"
  }
}

# Redshift 보안 그룹
resource "aws_security_group" "redshift_sg" {
  count = var.create_redshift ? 1 : 0
  
  name_prefix = "${var.project_name}-redshift-sg-"
  vpc_id      = module.vpc_db.vpc_id

  # Redshift 포트 (5439) - EKS 클러스터에서만 접근 허용
  ingress {
    from_port       = 5439
    to_port         = 5439
    protocol        = "tcp"
    security_groups = var.create_eks_cluster ? [module.eks[0].node_security_group_id] : []
    description     = "Allow Redshift access from EKS nodes"
  }

  # VPC-APP에서도 접근 허용 (Airflow 등에서 접근 가능하도록)
  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.vpc_app_cidr]
    description = "Allow Redshift access from VPC-APP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-redshift-sg"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Redshift IAM Role (S3 COPY 작업용)
resource "aws_iam_role" "redshift_s3_copy_role" {
  count = var.create_redshift ? 1 : 0
  
  name = "${var.project_name}-redshift-s3-copy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-redshift-s3-copy-role"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Redshift S3 COPY 정책
resource "aws_iam_policy" "redshift_s3_copy_policy" {
  count = var.create_redshift ? 1 : 0
  
  name        = "${var.project_name}-redshift-s3-copy-policy"
  description = "Policy for Redshift to access S3 for COPY operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_raw_data_bucket}",
          "arn:aws:s3:::${var.s3_raw_data_bucket}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-redshift-s3-copy-policy"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# IAM Role에 정책 연결
resource "aws_iam_role_policy_attachment" "redshift_s3_copy_policy_attachment" {
  count = var.create_redshift ? 1 : 0
  
  role       = aws_iam_role.redshift_s3_copy_role[0].name
  policy_arn = aws_iam_policy.redshift_s3_copy_policy[0].arn
}
