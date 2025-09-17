# NodePool for Spark Executor workloads (ARM64 On-Demand)
resource "kubernetes_manifest" "karpenter_nodepool_spark_exec" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "spark-exec-arm-ondemand"
    }
    spec = {
      # Template for node configuration
      template = {
        metadata = {
          labels = {
            "workload"  = "spark-exec"
            "node-type" = "spark-exec-arm-ondemand"
          }
        }
        spec = {
          # Taints for dedicated Spark Executor nodes
          taints = [
            {
              key    = "workload"
              value  = "spark-exec"
              effect = "NoSchedule"
            }
          ]

          # Requirements for instance selection
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["m", "c"]  # Memory/Compute optimized instances
            },
            # 인스턴스 타입 제한 제거 - Karpenter가 자동으로 선택
            # {
            #   key      = "node.kubernetes.io/instance-type"
            #   operator = "In"
            #   values   = ["m6g.medium", "m6g.large", "c6g.medium", "c6g.large"]
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
            name = "spark-exec-al2023-arm64"
          }
        }
      }

      # Disruption settings (Spark Executor는 작업 완료 후 종료)
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
        expireAfter         = "2h"  # Spark 작업 완료 후 2시간 유지
      }

      # Resource limits
      limits = {
        cpu    = "8"
        memory = "32Gi"
      }

      # Weight for node pool priority
      weight = 70
    }
  }

  depends_on = [
    helm_release.karpenter,
    kubernetes_manifest.karpenter_ec2nodeclass_spark_exec
  ]
}


