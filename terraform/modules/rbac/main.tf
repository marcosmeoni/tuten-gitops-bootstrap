## RBAC: Developer role — read-only on pods/logs, deploy access on apps namespace

resource "kubernetes_role" "developer" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "developer"
    namespace = each.key
    labels    = var.labels
  }

  # Allow reading workloads
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

## RBAC: ArgoCD service account — full access for GitOps deploys

resource "kubernetes_role" "argocd_deployer" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "argocd-deployer"
    namespace = each.key
    labels    = var.labels
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
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
