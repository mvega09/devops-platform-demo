# ============================================================================
# OUTPUTS
# ============================================================================

output "argocd_namespace" {
  description = "Namespace donde está desplegado ArgoCD"
  value       = helm_release.argocd.namespace
}

output "argocd_version" {
  description = "Versión del chart de ArgoCD instalado"
  value       = helm_release.argocd.version
}

output "monitoring_namespace" {
  description = "Namespace donde está desplegado el stack de monitoreo"
  value       = var.enable_monitoring ? kubernetes_namespace_v1.monitoring[0].metadata[0].name : "monitoring disabled"
}

output "prometheus_version" {
  description = "Versión del chart de Prometheus instalado"
  value       = var.enable_monitoring ? helm_release.prometheus_stack[0].version : "monitoring disabled"
}

output "argocd_application_name" {
  description = "Nombre de la aplicación de ArgoCD"
  value       = kubectl_manifest.devops_platform_app.name
}

output "argocd_password_command" {
  description = "Comando para obtener la contraseña de ArgoCD"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
}

output "grafana_password_command" {
  description = "Comando para obtener la contraseña de Grafana"
  value       = var.enable_monitoring ? "kubectl get secret -n monitoring monitoring-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d" : "monitoring disabled"
}