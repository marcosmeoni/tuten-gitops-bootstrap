terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  backend "s3" {
    # OCI Object Storage compatible backend
    # Configure via env vars or terraform init -backend-config
    # OCI_BUCKET, OCI_ENDPOINT, OCI_REGION
  }
}

provider "kubernetes" {
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
