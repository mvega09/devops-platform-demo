# Configuración de los proveedores
provider "kubernetes" {
  config_path = "~/.kube/config" # Ruta a tu config de Minikube
  config_context = "minikube" # Forzamos a que use Minikube
}

provider "helm" {
  kubernetes = {
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