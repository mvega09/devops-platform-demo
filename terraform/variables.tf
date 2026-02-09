# ============================================================================
# VARIABLES CONFIGURATION
# ============================================================================

variable "kubernetes_config_path" {
  description = "Ruta al archivo de configuración de Kubernetes"
  type        = string
  default     = "~/.kube/config"
}

variable "kubernetes_context" {
  description = "Contexto de Kubernetes a utilizar"
  type        = string
  default     = "minikube"
}

variable "environment" {
  description = "Ambiente de despliegue (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "El ambiente debe ser: development, staging o production"
  }
}

variable "git_repo_url" {
  description = "URL del repositorio Git para ArgoCD"
  type        = string
  default     = "https://github.com/mvega09/devops-platform-demo.git"
}

variable "git_revision" {
  description = "Branch o tag del repositorio Git"
  type        = string
  default     = "HEAD"
}

variable "enable_monitoring" {
  description = "Habilitar stack de monitoreo (Prometheus + Grafana)"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Contraseña del admin de Grafana"
  type        = string
  default     = "admin"
  sensitive   = true
}