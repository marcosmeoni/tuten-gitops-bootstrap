## RBAC: Developer role — read-only on pods/logs, port-forward for debugging (non-prod only)

resource "kubernetes_role" "developer" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "developer"
    namespace = each.key
    labels    = var.labels
  }

  rule {
    api_groups = ["", "apps", "batch"]
    resources  = ["pods", "pods/log", "deployments", "replicasets", "jobs", "cronjobs", "services", "endpoints", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  # Allow port-forwarding for debugging (non-prod only)
  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create", "get"]
  }
}

resource "kubernetes_role_binding" "developer_binding" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "developer-binding"
    namespace = each.key
    labels    = var.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.developer[each.key].metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "tutenlabs:developers"
    api_group = "rbac.authorization.k8s.io"
  }
}

## FIX-03: ArgoCD deployer — explicit resource list instead of wildcard ["*"]
## Principle of least privilege: only resources ArgoCD actually needs to manage apps.

resource "kubernetes_role" "argocd_deployer" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "argocd-deployer"
    namespace = each.key
    labels    = var.labels
  }

  # Core workload management
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Core resources
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "configmaps", "serviceaccounts", "persistentvolumeclaims", "events"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Networking
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Batch workloads
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # RBAC (ArgoCD manages service accounts and roles for apps)
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # HPA
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "argocd_deployer_binding" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "argocd-deployer-binding"
    namespace = each.key
    labels    = var.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.argocd_deployer[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller"
    namespace = "argocd"
  }
}
