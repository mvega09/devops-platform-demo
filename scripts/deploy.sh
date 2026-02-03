#!/usr/bin/env bash
set -e

CLUSTER_NAME="minikube"
NAMESPACE="devops-demo"
K8S_PATH="k8s/base"
SERVICE_NAME="devops-platform"

echo "🚀 Iniciando despliegue local DevOps Platform"

# -------- Minikube --------
if minikube status >/dev/null 2>&1; then
  echo "✅ Minikube ya existe"
  minikube start
else
  echo "🆕 Minikube no existe. Creando cluster..."
  minikube start --driver=docker
fi

# -------- Contexto kubectl --------
kubectl config use-context minikube

echo "🔍 Verificando acceso al cluster..."
kubectl get nodes

# -------- Namespace --------
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "✅ Namespace $NAMESPACE existe"
else
  echo "🆕 Creando namespace $NAMESPACE"
  kubectl create namespace "$NAMESPACE"
fi

# -------- Deploy --------
echo "📦 Aplicando manifests Kubernetes..."
kubectl apply -f "$K8S_PATH" -n "$NAMESPACE"

# -------- Esperar Pods --------
echo "⏳ Esperando que los pods estén listos..."
kubectl wait --for=condition=Available deployment/$SERVICE_NAME \
  -n "$NAMESPACE" --timeout=120s

# -------- Estado --------
kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"

# -------- Exponer servicio --------
echo "🌐 Exponiendo servicio..."
minikube service "$SERVICE_NAME" -n "$NAMESPACE"
