# NodePool for LLM workloads (ARM64 On-Demand)
resource "kubernetes_manifest" "karpenter_nodepool_llm" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "llm-arm-ondemand"
    }
    spec = {
      # Template for node configuration
      template = {
        metadata = {
          labels = {
            "workload"  = "llm-model"
            "node-type" = "llm-arm-ondemand"
          }
        }
        spec = {
          # Taints for dedicated LLM nodes
          taints = [
            {
              key    = "workload"
              value  = "llm-model"
              effect = "NoSchedule"
            }
          ]

          # Requirements for instance selection
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["t"]
            },
            # 인스턴스 타입 제한 제거 - Karpenter가 자동으로 선택
            # {
            #   key      = "node.kubernetes.io/instance-type"
            #   operator = "In"
            #   values   = [var.llm_instance_type]
            # },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["arm64"]
            }
          ]

          # Node class reference
          nodeClassRef = {
            name = "llm-al2023-arm64"
          }
        }
      }

      # Disruption settings (consolidation disabled for stability)
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
        expireAfter         = "720h" # 30 days
      }

      # Resource limits - 현실적인 값으로 조정
      limits = {
        cpu    = "16"
        memory = "64Gi"
      }

      # Weight for node pool priority
      weight = 100
    }
  }

  depends_on = [
    helm_release.karpenter,
    kubernetes_manifest.karpenter_ec2nodeclass_llm
  ]
}
