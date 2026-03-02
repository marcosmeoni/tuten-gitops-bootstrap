variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "uat"], var.environment)
    error_message = "This repo only manages non-prod environments (dev, uat). PRD is out of scope."
  }
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context name for DEV cluster"
  type        = string
  default     = "tutenlabs-dev"
}

variable "namespaces" {
  description = "List of namespaces to create"
  type        = list(string)
  default = [
    "apps-dev",
    "monitoring-dev",
    "argocd",
    "ingress-nginx",
  ]
}
