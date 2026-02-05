#!/bin/bash

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}🗑️  Iniciando destrucción de DevOps Platform...${NC}"

# 1. Detener port-forward de ArgoCD si está corriendo
echo -e "${BLUE}🔌 Deteniendo port-forward de ArgoCD...${NC}"
pkill -f "port-forward.*argocd-server" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Port-forward de ArgoCD detenido.${NC}"
else
    echo -e "${YELLOW}⚠️  No se encontró port-forward activo.${NC}"
fi

# 2. Destruir infraestructura con Terraform
echo -e "${BLUE}🔥 Destruyendo recursos de Terraform...${NC}"
cd terraform

# Verificar si Terraform está inicializado
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠️  Terraform no está inicializado. Inicializando...${NC}"
    terraform init
fi

# Destruir en el orden inverso al despliegue
echo -e "${YELLOW}📋 Eliminando Application de ArgoCD...${NC}"
terraform destroy -target=kubernetes_manifest.devops_platform_app -auto-approve

echo -e "${YELLOW}📋 Eliminando ArgoCD Helm Release...${NC}"
terraform destroy -target=helm_release.argocd -auto-approve

# Destruir todo lo restante
echo -e "${RED}🔥 Destruyendo todos los recursos restantes...${NC}"
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Terraform destruido con éxito.${NC}"
else
    echo -e "${RED}❌ Error al destruir recursos con Terraform.${NC}"
    echo -e "${YELLOW}⚠️  Continuando con limpieza manual...${NC}"
fi

cd ..

# 3. Limpiar namespace de ArgoCD (por si quedó algo)
echo -e "${BLUE}🧹 Limpiando namespace de ArgoCD...${NC}"
kubectl delete namespace argocd --timeout=60s 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Namespace argocd eliminado.${NC}"
else
    echo -e "${YELLOW}⚠️  Namespace argocd no existe o ya fue eliminado.${NC}"
fi

# 4. Limpiar recursos de la aplicación en default namespace
echo -e "${BLUE}🧹 Limpiando recursos de la aplicación...${NC}"
kubectl delete all -l app=devops-platform -n default --timeout=60s 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Recursos de la aplicación eliminados.${NC}"
fi

# 5. Verificar estado final
echo -e "${BLUE}📊 Estado final de namespaces:${NC}"
kubectl get namespaces | grep -E "argocd|default"

# 6. Opción para detener Minikube
echo ""
echo -e "${YELLOW}❓ ¿Deseas detener Minikube también? (y/n)${NC}"
read -r STOP_MINIKUBE

if [[ "$STOP_MINIKUBE" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🛑 Deteniendo Minikube...${NC}"
    minikube stop
    echo -e "${GREEN}✅ Minikube detenido.${NC}"
else
    echo -e "${YELLOW}⚠️  Minikube sigue en ejecución.${NC}"
fi

# 7. Resumen final
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         🎉 DevOps Platform Destruido con Éxito 🎉        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📝 Comandos útiles para verificar:${NC}"
echo -e "   • Ver namespaces: ${YELLOW}kubectl get namespaces${NC}"
echo -e "   • Ver todos los pods: ${YELLOW}kubectl get pods --all-namespaces${NC}"
echo -e "   • Estado de Minikube: ${YELLOW}minikube status${NC}"
echo ""
echo -e "${YELLOW}💡 Para eliminar completamente Minikube: ${NC}minikube delete"
echo ""