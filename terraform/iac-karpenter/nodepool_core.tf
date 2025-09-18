# NodePool for Core workloads (v1beta1 API)
resource "kubernetes_manifest" "karpenter_nodepool_core" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "core-arm-ondemand"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload"  = "core"
            "node-type" = "core-arm-ondemand"
          }
        }
        spec = {
          nodeClassRef = {
            apiVersion = "karpenter.k8s.aws/v1beta1"
            kind       = "EC2NodeClass"
            name       = "core-arm-ondemand"
          }

          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["arm64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            # 인스턴스 타입 제한 제거 - Karpenter가 자동으로 선택
            # {
            #   key      = "node.kubernetes.io/instance-type"
            #   operator = "In"
            #   values   = ["t4g.medium", "t4g.large"]
            # }
          ]

          taints = []
        }
      }

      # 과도한 인스턴스 생성 방지를 위한 적절한 제한
      limits = {
        cpu    = "8"    # 현실적인 값으로 조정
        memory = "32Gi" # 현실적인 값으로 조정
      }

      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        expireAfter         = "30m" # 1h에서 30m으로 단축
      }

      weight = 100
    }
  }

  depends_on = [kubernetes_manifest.karpenter_ec2nodeclass_core]
}
