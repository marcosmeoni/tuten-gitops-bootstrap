resource "kubernetes_namespace" "this" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.key
    labels = merge(var.labels, {
      "kubernetes.io/metadata.name" = each.key
    })
    annotations = {
      "managed-by"  = "terraform"
      "environment" = var.environment
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["kubectl.kubernetes.io/last-applied-configuration"],
    ]
  }
}

resource "kubernetes_resource_quota" "this" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "default-quota"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    labels    = var.labels
  }

  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "4Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "8Gi"
      "pods"            = "20"
    }
  }
}

resource "kubernetes_limit_range" "this" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
    labels    = var.labels
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "200m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}
