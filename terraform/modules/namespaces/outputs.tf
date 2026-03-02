output "namespace_names" {
  description = "Created namespace names"
  value       = [for ns in kubernetes_namespace.this : ns.metadata[0].name]
}
