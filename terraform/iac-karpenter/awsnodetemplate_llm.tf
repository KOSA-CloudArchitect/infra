# AWSNodeTemplate for LLM workloads (ARM64 AL2)
resource "kubernetes_manifest" "karpenter_awsnodetemplate_llm" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1alpha1"
    kind       = "AWSNodeTemplate"
    metadata = {
      name = "llm-arm-ondemand"
      labels = {
        "karpenter.sh/discovery" = var.cluster_name
      }
    }
    spec = {
      # Subnet selector using discovery tags (App Private 서브넷만)
      subnetSelector = {
        "karpenter.sh/discovery" = var.cluster_name
        "Name"                   = "hihypipe-vpc-app-private-*" # App Private 서브넷만 선택
      }
      # Security group selector using cluster name tag
      securityGroupSelector = {
        "aws:eks:cluster-name" = var.cluster_name
      }
      # Instance profile for Karpenter-managed nodes
      instanceProfile = aws_iam_instance_profile.karpenter_node.name
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
        "workload"                                  = "llm"
        "karpenter.sh/discovery"                    = var.cluster_name
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
        "node-type"                                 = "llm-arm-ondemand"
      })
      # AMI family for ARM64 instances (EKS 1.32 호환)
      amiFamily = "AL2"
      # Explicit AMI ID for EKS 1.32 ARM64 (EKS 1.33 호환)
      amiSelector = {
        "karpenter.k8s.aws/ami-id" = "ami-02b221113b5ddb64d"
      }
    }
  }

  depends_on = [
    helm_release.karpenter
  ]
}
