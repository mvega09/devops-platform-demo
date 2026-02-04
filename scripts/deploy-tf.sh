#!/bin/bash

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Iniciando automatización DevOps Platform...${NC}"

# 1. Verificar si Minikube está corriendo
if ! minikube status > /dev/null 2>&1; then
    echo -e "${BLUE}🟡 Minikube no está iniciado. Iniciando...${NC}"
    minikube start --driver=docker
else
    echo -e "${GREEN}✅ Minikube ya está en ejecución.${NC}"
fi

# 2. Inicializar y aplicar Terraform
echo -e "${BLUE}🏗️  Configurando infraestructura con Terraform...${NC}"
cd terraform
terraform init

# Fase 1: Instalar solo ArgoCD (esto crea los CRDs)
terraform apply -target=helm_release.argocd -auto-approve

# Fase 2: Instalar el resto (la Aplicación de ArgoCD)
terraform apply -auto-approve

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Terraform aplicado con éxito.${NC}"
else
    echo "❌ Error en Terraform. Abortando."
    exit 1
fi

# 3. Esperar a que ArgoCD esté listo
echo -e "${BLUE}⏳ Esperando a que los componentes de ArgoCD se estabilicen...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 4. Obtener credenciales de ArgoCD
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}🔐 Credenciales de ArgoCD:${NC}"
echo "   Usuario: admin"
echo "   Password: $ARGOCD_PWD"

# 5. Mostrar URL de acceso
echo -e "${BLUE}🌐 Para acceder a la UI de ArgoCD, ejecuta en otra terminal:${NC}"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"

# 6. Estado de la aplicación
echo -e "${BLUE}📊 Estado actual de los recursos de la App:${NC}"
kubectl get pods,svc -n default