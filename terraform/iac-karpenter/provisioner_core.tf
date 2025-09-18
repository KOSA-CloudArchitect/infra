# Karpenter Provisioner for Core workloads (Jenkins, etc.)
resource "kubernetes_manifest" "karpenter_provisioner_core" {
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "core-arm-ondemand"
    }
    spec = {
      # Provider reference to AWSNodeTemplate
      providerRef = {
        name = "llm-arm-ondemand"
      }
      # Requirements for instance selection
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
      # No taints for general workloads
      taints = []
      # Labels for node identification
      labels = {
        "workload"  = "core"
        "node-type" = "core-arm-ondemand"
      }
      # Consolidation settings (enabled for general workloads)
      consolidation = {
        enabled = true
      }
      # TTL settings (only use ttlSecondsUntilExpired when consolidation is enabled)
      ttlSecondsUntilExpired = 3600
      # Resource limits
      limits = {
        resources = {
          cpu    = "1000"
          memory = "1000Gi"
        }
      }
      # Weight for provisioner priority
      weight = 100
      # Startup taints (optional)
      startupTaints = []
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_awsnodetemplate_llm
  ]
}
