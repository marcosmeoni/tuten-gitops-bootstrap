terraform {
  # FIX-10: Pin version range with upper bound to prevent breaking changes on major Terraform releases
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  # FIX-01: Backend variables are supplied via -backend-config at init time (no hardcoded values).
  # Required vars: bucket, endpoint, region, key, access_key, secret_key
  # Usage: terraform init -backend-config=backend-dev.hcl
  backend "s3" {}
}

# FIX-02: Provider supports exec-based auth (token from env) to avoid kubeconfig drift in CI.
# In CI: set KUBE_HOST, KUBE_TOKEN, KUBE_CA_CERT env vars instead of relying on file.
provider "kubernetes" {
  # kubeconfig_path is only used locally; CI uses environment variables.
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

module "namespaces" {
  source      = "../../modules/namespaces"
  environment = var.environment
  namespaces  = var.namespaces
  labels      = local.common_labels
}

module "rbac" {
  source      = "../../modules/rbac"
  environment = var.environment
  namespaces  = var.namespaces
  labels      = local.common_labels
}

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
    "platform"                     = "tutenlabs"
    "gitops"                       = "true"
  }
}
