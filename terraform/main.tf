terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0" # Forzamos una versión moderna
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.0"
    }
  }
}

# Configuración de los proveedores
provider "kubernetes" {
  config_path = "~/.kube/config" # Ruta a tu config de Minikube
  config_context = "minikube" # Forzamos a que use Minikube
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "minikube"
  }
}

# 1. Instalar ArgoCD usando su Chart oficial de Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.7"
}

# 2. Definir la Aplicación en ArgoCD (El puente GitOps)
resource "kubernetes_manifest" "devops_platform_app" {
  depends_on = [helm_release.argocd]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "devops-platform"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        # ¡IMPORTANTE! Cambia esto por la URL de TU repositorio de GitHub
        repoURL        = "https://github.com/mvega09/devops-platform-demo.git"
        targetRevision = "HEAD"
        path           = "charts/devops-platform" # Ruta donde creaste el chart
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}

# Namespace para monitoreo
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Helm Release para Kube-Prometheus-Stack
resource "helm_release" "prometheus_stack" {
  name       = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name # Usamos la referencia dinámica
  
  # Forzamos la creación del namespace si no existe (doble seguridad)
  create_namespace = true

  # Habilitamos Grafana y configuramos acceso básico
  # Nota: El bloque set DEBE ir sin el signo "=" antes de la llave
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }
}