locals {
  autoscaler_release = yamlencode({
    "nameOverride"     = "cluster-autoscaler"
    "fullnameOverride" = "cluster-autoscaler"
    "cloudProvider"    = "aws"
    "awsRegion"        = data.aws_region.current.name
    "tolerations"      = local.autoscaler_tolerations
    "nodeSelector"     = local.autoscaler_nodeselector
    "autoDiscovery" = {
      "clusterName" = local.cluster_id
    }
    "image" = {
      tag = local.ca_image_tag
    }
    "extraArgs" = merge({
      "expander"                      = "priority"
      "balance-similar-node-groups"   = true
      "skip-nodes-with-system-pods"   = false
      "skip-nodes-with-local-storage" = false
      "expander"                      = "least-waste"
    }, local.args),
    "rbac" = {
      "serviceAccount" = {
        "name" = "cluster-autoscaler"
        "annotations" = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
        }
      }
    }
  })

  daemonset_release = yamlencode({
    failOnInitError = false
    nodeSelector    = local.gpu_node_labels
    tolerations     = local.daemonset_tolerations
  })
}

resource "helm_release" "cluster-autoscaler" {
  count = local.deploy_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  namespace  = local.autoscaler_namespace
  version    = local.ca_version
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  values     = [local.autoscaler_release]

}

resource "helm_release" "nvidia-plugin" {
  count = local.deploy_nvidia_plugin ? 1 : 0

  name       = "nvidia-plugin"
  namespace  = "kube-system" # we should hard code this here
  version    = local.nvidia_version
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"

  // Prevents it crashing on non-gpu nodes
  values = [local.daemonset_release]
}
