# EC2NodeClass for Core workloads (v1beta1 API)
resource "kubernetes_manifest" "karpenter_ec2nodeclass_core" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "core-arm-ondemand"
    }
    spec = {
      amiFamily = "AL2023"                         # Amazon Linux 2023 사용
      role      = aws_iam_role.karpenter_node.name # Terraform 리소스 참조

      # userData 제거 - Karpenter가 자동으로 부트스트랩 처리

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]

      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = "30Gi"
            volumeType          = "gp3"
            deleteOnTermination = true
            encrypted           = true
            iops                = 3000
            throughput          = 125
          }
        }
      ]

      tags = {
        Name                     = "karpenter-core-node"
        NodeType                 = "core-workload"
        workload                 = "core"
        "karpenter.sh/discovery" = var.cluster_name
      }
    }
  }

  depends_on = [
    aws_iam_instance_profile.karpenter_node,
    helm_release.karpenter
  ]
}
