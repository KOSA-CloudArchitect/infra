# EC2NodeClass for Kafka workloads (ARM64 AL2023)
resource "kubernetes_manifest" "karpenter_ec2nodeclass_kafka" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "kafka-al2023-arm64"
      labels = {
        "karpenter.sh/discovery" = var.cluster_name
      }
    }
    spec = {
      # AMI family for EKS 1.33 ARM64 (AL2023)
      amiFamily = "AL2023"

      # Subnet selector using discovery tags
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]

      # Security group selector using discovery tags
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]

      # Instance profile for Karpenter-managed nodes
      role = aws_iam_role.karpenter_node.name

      # Block device mappings for EBS root volume (Kafka needs more storage)
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = "50Gi"  # Kafka용으로 더 큰 볼륨
            volumeType          = "gp3"
            iops                = 3000
            throughput          = 125
            deleteOnTermination = true
            encrypted           = true
          }
        }
      ]

      # userData 제거 - Karpenter가 자동으로 부트스트랩 처리

      # Tags for Kafka workload identification
      tags = merge(var.additional_tags, {
        Name                     = "karpenter-kafka-node"
        "workload"               = "kafka"
        "karpenter.sh/discovery" = var.cluster_name
        "node-type"              = "kafka-arm-ondemand"
        "storage-type"           = "ebs"
      })
    }
  }

  depends_on = [
    aws_iam_instance_profile.karpenter_node,
    helm_release.karpenter
  ]
}

