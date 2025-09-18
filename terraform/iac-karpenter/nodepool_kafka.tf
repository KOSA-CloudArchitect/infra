# NodePool for Kafka workloads (ARM64 On-Demand)
resource "kubernetes_manifest" "karpenter_nodepool_kafka" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "kafka-arm-ondemand"
    }
    spec = {
      # Template for node configuration
      template = {
        metadata = {
          labels = {
            "workload"  = "kafka"
            "node-type" = "kafka-arm-ondemand"
            "storage-type" = "ebs"
          }
        }
        spec = {
          # Taints for dedicated Kafka nodes
          taints = [
            {
              key    = "workload"
              value  = "kafka"
              effect = "NoSchedule"
            }
          ]

          # Requirements for instance selection
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["m", "r"]  # Memory/Storage optimized instances
            },
            # 인스턴스 타입 제한 제거 - Karpenter가 자동으로 선택
            # {
            #   key      = "node.kubernetes.io/instance-type"
            #   operator = "In"
            #   values   = ["m6g.medium", "m6g.large", "m6g.xlarge", "r6g.medium", "r6g.large"]
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
            name = "kafka-al2023-arm64"
          }
        }
      }

      # Disruption settings (Kafka는 안정성이 중요하므로 보수적 설정)
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "60s"
        expireAfter         = "24h"  # Kafka는 24시간 유지
      }

      # Resource limits (Kafka는 스토리지가 중요)
      limits = {
        cpu    = "4"
        memory = "16Gi"
      }

      # Weight for node pool priority
      weight = 80
    }
  }

  depends_on = [
    helm_release.karpenter,
    kubernetes_manifest.karpenter_ec2nodeclass_kafka
  ]
}


