# Karpenter Provisioner for Core workloads - without capacity-type
resource "kubernetes_manifest" "karpenter_provisioner_core_no_capacity" {
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "core-no-capacity"
    }
    spec = {
      # Provider reference to AWSNodeTemplate
      providerRef = {
        name = "llm-arm-ondemand"
      }
      # Requirements for instance selection - capacity-type 제외
      requirements = [
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["arm64"]
        },
        {
          key      = "node.kubernetes.io/instance-type"
          operator = "In"
          values   = ["t4g.medium", "t4g.large"]
        }
      ]
      # Labels for node identification
      labels = {
        "workload"  = "core"
        "node-type" = "core-no-capacity"
      }
      # Resource limits
      limits = {
        resources = {
          cpu    = "1000"
          memory = "1000Gi"
        }
      }
      # Weight for provisioner priority
      weight = 100
      # Consolidation 비활성화 (capacity-type과 충돌 방지)
      consolidation = {
        enabled = false
      }
      # TTL 설정
      ttlSecondsAfterEmpty   = 300
      ttlSecondsUntilExpired = 3600
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_awsnodetemplate_llm
  ]
}
