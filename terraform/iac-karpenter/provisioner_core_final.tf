# Karpenter Provisioner for Core workloads - final version without capacity-type
resource "kubernetes_manifest" "karpenter_provisioner_core_final" {
  manifest = {
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "core-final"
    }
    spec = {
      # Inline provider configuration for v0.16.3 compatibility
      provider = {
        subnetSelector = {
          "karpenter.sh/discovery" = "hihypipe-eks-cluster"
        }
        securityGroupSelector = {
          "aws:eks:cluster-name" = "hihypipe-eks-cluster"
        }
        instanceProfile = "KarpenterNodeInstanceProfile-hihypipe-eks-cluster"
        amiFamily       = "AL2"
        blockDeviceMappings = [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeSize          = "100Gi"
              volumeType          = "gp3"
              deleteOnTermination = true
              encrypted           = true
              iops                = 3000
              throughput          = 125
            }
          }
        ]
        tags = {
          "Name"                   = "karpenter-core-node"
          "NodeType"               = "core-workload"
          "workload"               = "core"
          "karpenter.sh/discovery" = "hihypipe-eks-cluster"
        }
      }

      # Requirements for instance selection - capacity-type 포함
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
        }
        # 인스턴스 타입 제한 임시 제거 (테스트 후 재추가)
      ]
      # Labels for node identification
      labels = {
        "workload"  = "core"
        "node-type" = "core-final"
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
      # Consolidation 비활성화
      consolidation = {
        enabled = false
      }
      # TTL 설정
      ttlSecondsAfterEmpty   = 300
      ttlSecondsUntilExpired = 3600
    }
  }

  # depends_on 제거 - inline provider 사용으로 AWSNodeTemplate 불필요
}
