# =============================================================================
# RDS PostgreSQL Database for Airflow
# =============================================================================

# RDS 서브넷 그룹 (VPC-DB의 프라이빗 서브넷 사용)
resource "aws_db_subnet_group" "rds_subnet_group" {
  count = var.create_rds ? 1 : 0
  
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = module.vpc_db.private_subnets

  tags = {
    Name        = "${var.project_name}-rds-subnet-group"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# RDS 보안 그룹 (EKS 클러스터에서만 접근 허용)
resource "aws_security_group" "rds_sg" {
  count = var.create_rds ? 1 : 0
  
  name_prefix = "${var.project_name}-rds-sg-"
  vpc_id      = module.vpc_db.vpc_id

  # PostgreSQL 포트 (5432) - EKS 클러스터에서만 접근 허용
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.create_eks_cluster ? [module.eks[0].node_security_group_id] : []
    description     = "Allow PostgreSQL access from EKS nodes"
  }

  # VPC-APP에서도 접근 허용 (Jenkins 등에서 접근 가능하도록)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_app_cidr]
    description = "Allow PostgreSQL access from VPC-APP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# RDS PostgreSQL 인스턴스
resource "aws_db_instance" "airflow_db" {
  count = var.create_rds ? 1 : 0
  
  # 기본 설정
  identifier = "${var.project_name}-airflow-db"
  
  # 엔진 설정
  engine         = var.rds_engine
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class
  
  # 스토리지 설정
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = var.rds_storage_encrypted
  
  # 데이터베이스 설정
  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = var.rds_master_password
  
  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group[0].name
  vpc_security_group_ids = [aws_security_group.rds_sg[0].id]
  publicly_accessible    = false  # 프라이빗 서브넷에만 배치
  
  # 백업 설정
  backup_retention_period = var.rds_backup_retention_period
  backup_window          = var.rds_backup_window
  maintenance_window     = var.rds_maintenance_window
  
  # 고가용성 설정
  multi_az = var.rds_multi_az
  
  # 보안 설정
  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
  
  # 모니터링 설정
  monitoring_interval = 0  # 테스트 환경에서는 Enhanced Monitoring 비활성화
  monitoring_role_arn = null
  
  # 성능 인사이트
  performance_insights_enabled = false  # 테스트 환경에서는 비활성화
  
  tags = {
    Name        = "${var.project_name}-airflow-db"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Purpose     = "Airflow Metadata Database"
  }
}

# RDS 엔드포인트 출력을 위한 데이터 소스
data "aws_db_instance" "airflow_db" {
  count = var.create_rds ? 1 : 0
  
  db_instance_identifier = aws_db_instance.airflow_db[0].identifier
  depends_on             = [aws_db_instance.airflow_db]
}
