# AWSNodeTemplate for Core workloads - 주석 처리 (inline provider 사용)
# resource "kubernetes_manifest" "karpenter_awsnodetemplate_core" {
#   manifest = {
#     apiVersion = "karpenter.k8s.aws/v1alpha1"
#     kind       = "AWSNodeTemplate"
#     metadata = {
#       name = "core-arm-ondemand"
#     }
#     spec = {
#       # Subnet selector using discovery tags
#       subnetSelector = {
#         "karpenter.sh/discovery" = "hihypipe-eks-cluster"
#       }
#       # Security group selector using cluster tags
#       securityGroupSelector = {
#         "aws:eks:cluster-name" = "hihypipe-eks-cluster"
#       }
#       # Instance profile for Karpenter nodes
#       instanceProfile = "KarpenterNodeInstanceProfile-hihypipe-eks-cluster"
#       # AMI family for ARM64
#       amiFamily = "AL2"
#       # User data for node initialization
#       userData = base64encode(<<-EOT
#         #!/bin/bash
#         /etc/eks/bootstrap.sh hihypipe-eks-cluster
#         EOT
#       )
#       # Block device mappings for root volume
#       blockDeviceMappings = [
#         {
#           deviceName = "/dev/xvda"
#           ebs = {
#             volumeSize = "100Gi"
#             volumeType = "gp3"
#             iops       = 3000
#             throughput = 125
#             encrypted  = true
#           }
#         }
#       ]
#       # Tags for the instances
#       tags = {
#         "Name"                   = "karpenter-core-node"
#         "NodeType"               = "core-workload"
#         "workload"               = "core"
#         "karpenter.sh/discovery" = "hihypipe-eks-cluster"
#       }
#     }
#   }
# }