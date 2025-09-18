# Karpenter Provisioner for LLM workloads (ARM64 On-Demand)
resource "kubernetes_manifest" "karpenter_provisioner_llm" {
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "llm-arm-ondemand"
    }
    spec = {
      # Provider reference to AWSNodeTemplate
      providerRef = {
        name = "llm-arm-ondemand"
      }
      # Requirements for instance selection
      requirements = [
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["on-demand"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["arm64"]
        },
        {
          key      = "node.kubernetes.io/instance-type"
          operator = "In"
          values   = [var.llm_instance_type]
        }
      ]
      # Taints for dedicated LLM nodes
      taints = [
        {
          key    = "workload"
          value  = "llm-model"
          effect = "NoSchedule"
        }
      ]
      # Labels for node identification
      labels = {
        "workload"  = "llm-model"
        "node-type" = "llm-arm-ondemand"
      }
      # Consolidation settings (disabled for stability)
      consolidation = {
        enabled = false
      }
      # TTL settings
      ttlSecondsAfterEmpty   = 3600    # 1 hour
      ttlSecondsUntilExpired = 2592000 # 30 days
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
