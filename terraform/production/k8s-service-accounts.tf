# =============================================================================
# Kubernetes Service Accounts for IRSA (별도 배포용)
# =============================================================================

# Airflow 서비스 어카운트
resource "kubernetes_service_account" "airflow_irsa" {
  count = var.create_s3_buckets && var.create_eks_cluster && var.create_k8s_resources ? 1 : 0
  
  metadata {
    name      = "airflow-irsa"
    namespace = "airflow"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.airflow_irsa[0].arn
    }
  }
  
  depends_on = [
    module.eks,
    kubernetes_namespace.airflow,
    aws_iam_role.airflow_irsa
  ]
}

# Spark 서비스 어카운트
resource "kubernetes_service_account" "spark_irsa" {
  count = var.create_s3_buckets && var.create_eks_cluster && var.create_k8s_resources ? 1 : 0
  
  metadata {
    name      = "spark-irsa"
    namespace = "spark"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.spark_irsa[0].arn
    }
  }
  
  depends_on = [
    module.eks,
    kubernetes_namespace.spark,
    aws_iam_role.spark_irsa
  ]
}

# Airflow 네임스페이스
resource "kubernetes_namespace" "airflow" {
  count = var.create_s3_buckets && var.create_eks_cluster && var.create_k8s_resources ? 1 : 0
  
  metadata {
    name = "airflow"
    labels = {
      name = "airflow"
      environment = var.environment
      project = var.project_name
    }
  }
  
  depends_on = [module.eks]
}

# Spark 네임스페이스
resource "kubernetes_namespace" "spark" {
  count = var.create_s3_buckets && var.create_eks_cluster && var.create_k8s_resources ? 1 : 0
  
  metadata {
    name = "spark"
    labels = {
      name = "spark"
      environment = var.environment
      project = var.project_name
    }
  }
  
  depends_on = [module.eks]
}
