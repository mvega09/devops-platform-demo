# ============================================================================
# TERRAFORM CONFIGURATION
# ============================================================================
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.10.0"
    }
  }
}

# ============================================================================
# PROVIDER CONFIGURATION
# ============================================================================
provider "kubernetes" {
  config_path    = pathexpand(var.kubernetes_config_path)
  config_context = var.kubernetes_context
}

provider "helm" {
  kubernetes {
    config_path    = pathexpand(var.kubernetes_config_path)
    config_context = var.kubernetes_context
  }
}

provider "kubectl" {
  config_path    = pathexpand(var.kubernetes_config_path)
  config_context = var.kubernetes_context
}

# ============================================================================
# LOCAL VARIABLES
# ============================================================================
locals {
  # Configuración general
  cluster_name = "devops-platform"

  # Namespaces
  argocd_namespace     = "argocd"
  monitoring_namespace = "monitoring"
  app_namespace        = "default"

  # Versiones de Charts
  argocd_chart_version     = "5.46.7"
  prometheus_chart_version = "81.5.1"

  # Configuración Git
  git_path = "charts/devops-platform"

  # Tags comunes para todos los recursos
  common_labels = {
    managed_by  = "terraform"
    environment = var.environment
    project     = local.cluster_name
  }
}

# ============================================================================
# ARGOCD INSTALLATION
# ============================================================================
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = local.argocd_namespace
  create_namespace = true
  version          = local.argocd_chart_version

  # Configuraciones de despliegue
  wait            = true
  wait_for_jobs   = true
  timeout         = 600
  cleanup_on_fail = true
  atomic          = false
  max_history     = 5

  # Configuraciones personalizadas de ArgoCD
  values = [
    yamlencode({
      global = {
        domain = "argocd.local"
      }
      server = {
        service = {
          type = "ClusterIP"
        }
        # extraArgs = [
        #   "--insecure" # Para desarrollo local
        # ]
      }
    })
  ]

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================================================
# WAIT FOR ARGOCD CRDs
# ============================================================================
resource "time_sleep" "wait_for_argocd_crds" {
  depends_on = [helm_release.argocd]

  create_duration  = "45s"
  destroy_duration = "10s"

  triggers = {
    argocd_version = helm_release.argocd.version
  }
}

# ============================================================================
# MONITORING NAMESPACE (conditional)
# ============================================================================
resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = local.monitoring_namespace

    labels = merge(
      local.common_labels,
      {
        name = local.monitoring_namespace
        type = "monitoring"
      }
    )
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ============================================================================
# PROMETHEUS STACK INSTALLATION (conditional)
# ============================================================================
resource "helm_release" "prometheus_stack" {
  count = var.enable_monitoring ? 1 : 0

  name       = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  version    = local.prometheus_chart_version

  # Configuraciones de despliegue
  wait             = true
  wait_for_jobs    = true
  timeout          = 600
  cleanup_on_fail  = true
  atomic           = false
  max_history      = 5
  create_namespace = false

  # Configuraciones de Grafana y Prometheus
  values = [
    yamlencode({
      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password
        service = {
          type = "ClusterIP"
        }
        persistence = {
          enabled = false # Cambiar a true para producción
        }
      }
      prometheus = {
        enabled = true
        prometheusSpec = {
          retention   = "7d"
          storageSpec = {}
        }
      }
      alertmanager = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.monitoring]

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================================================
# ARGOCD APPLICATION (GitOps Bridge)
# ============================================================================
resource "kubectl_manifest" "devops_platform_app" {
  depends_on = [
    helm_release.argocd
  ]

  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${local.cluster_name}
  namespace: ${local.argocd_namespace}
  labels:
    managed_by: terraform
    environment: ${var.environment}
    project: ${local.cluster_name}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: ${var.git_repo_url}
    targetRevision: ${var.git_revision}
    path: ${local.git_path}
    helm:
      valueFiles:
        - values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: ${local.app_namespace}

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
YAML
}
