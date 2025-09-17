# EC2NodeClass for LLM workloads (ARM64 AL2023)
resource "kubernetes_manifest" "karpenter_ec2nodeclass_llm" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "llm-al2023-arm64"
      labels = {
        "karpenter.sh/discovery" = var.cluster_name
      }
    }
    spec = {
      # AMI family for EKS 1.33 ARM64 (AL2023)
      amiFamily = "AL2023"

      # Subnet selector using discovery tags (App Private 서브넷만)
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery/${var.cluster_name}" = "*"
            "Name"                                       = "hihypipe-vpc-app-private-*"
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

      # Block device mappings for EBS root volume
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = "${var.llm_root_volume_size}Gi"
            volumeType          = "gp3"
            iops                = var.llm_root_volume_iops
            throughput          = var.llm_root_volume_throughput
            deleteOnTermination = true
            encrypted           = true
          }
        }
      ]

      # User data for node initialization
      userData = base64encode(<<-EOT
        #!/bin/bash
        /etc/eks/bootstrap.sh ${var.cluster_name}
        EOT
      )

      # Tags for LLM workload identification
      tags = merge(var.additional_tags, {
        "workload"               = "llm"
        "karpenter.sh/discovery" = var.cluster_name
        "node-type"              = "llm-arm-ondemand"
      })
    }
  }

  depends_on = [
    helm_release.karpenter
  ]
}
