# Karpenter Provisioner for Core workloads (Jenkins, etc.) - Simplified
resource "kubernetes_manifest" "karpenter_provisioner_core_simple" {
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "core-simple"
    }
    spec = {
      # Provider reference to AWSNodeTemplate
      providerRef = {
        name = "llm-arm-ondemand"
      }
      # Requirements for instance selection - only essential ones
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
        "node-type" = "core-simple"
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
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_awsnodetemplate_llm
  ]
}
