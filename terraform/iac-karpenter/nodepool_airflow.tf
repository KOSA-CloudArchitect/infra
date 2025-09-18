# NodePool for Airflow workloads (ARM64 On-Demand)
resource "kubernetes_manifest" "karpenter_nodepool_airflow" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "airflow-arm-ondemand"
    }
    spec = {
      # Template for node configuration
      template = {
        metadata = {
          labels = {
            "workload"  = "airflow"
            "node-type" = "airflow-arm-ondemand"
          }
        }
        spec = {
          # Taints for dedicated Airflow nodes
          taints = [
            {
              key    = "workload"
              value  = "airflow"
              effect = "NoSchedule"
            }
          ]

          # Requirements for instance selection
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["t", "m"]  # General purpose and memory optimized
            },
            # 인스턴스 타입 제한 제거 - Karpenter가 자동으로 선택
            # {
            #   key      = "node.kubernetes.io/instance-type"
            #   operator = "In"
            #   values   = ["t4g.medium", "t4g.large", "m6g.medium", "m6g.large"]
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
            name = "airflow-al2023-arm64"
          }
        }
      }

      # Disruption settings (Airflow는 워크플로우가 중요하므로 보수적 설정)
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "60s"
        expireAfter         = "12h"  # Airflow는 12시간 유지
      }

      # Resource limits
      limits = {
        cpu    = "4"
        memory = "16Gi"
      }

      # Weight for node pool priority
      weight = 60
    }
  }

  depends_on = [
    helm_release.karpenter,
    kubernetes_manifest.karpenter_ec2nodeclass_airflow
  ]
}


