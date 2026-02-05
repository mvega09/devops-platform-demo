#!/bin/bash

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Regresar al directorio anterior
cd ..

# 3. Esperar a que ArgoCD esté listo
echo -e "${BLUE}⏳ Esperando a que los componentes de ArgoCD se estabilicen...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ ArgoCD no está listo. Abortando.${NC}"
    exit 1
fi

# 4. Obtener credenciales de ArgoCD
echo -e "${BLUE}🔐 Obteniendo credenciales de ArgoCD...${NC}"
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [ -z "$ARGOCD_PWD" ]; then
    echo -e "${YELLOW}⚠️  No se pudo obtener la contraseña de ArgoCD automáticamente.${NC}"
else
    echo -e "${GREEN}✅ Credenciales de ArgoCD:${NC}"
    echo "   Usuario: admin"
    echo "   Password: $ARGOCD_PWD"
fi

# 5. Esperar a que la aplicación DevOps Platform esté sincronizada
echo -e "${BLUE}⏳ Esperando a que ArgoCD sincronice la aplicación...${NC}"
sleep 10

# Verificar que los pods de la aplicación estén listos
echo -e "${BLUE}⏳ Esperando a que los pods de la aplicación estén listos...${NC}"
kubectl wait --for=condition=ready --timeout=180s pod -l app=devops-platform -n default 2>/dev/null

# 6. Estado de la aplicación
echo -e "${BLUE}📊 Estado actual de los recursos de la App:${NC}"
kubectl get pods,svc -n default

# 7. Lanzar el túnel de ArgoCD en segundo plano
echo -e "${GREEN}🌐 Abriendo túnel de ArgoCD en segundo plano...${NC}"
# Matar cualquier port-forward previo en el puerto 8443
pkill -f "port-forward.*argocd-server" 2>/dev/null
kubectl port-forward svc/argocd-server -n argocd 8443:443 > /dev/null 2>&1 &
ARGOCD_PID=$!

echo -e "${GREEN}✅ ArgoCD UI disponible en: https://localhost:8443${NC}"
echo -e "${YELLOW}   (Acepta el certificado autofirmado en tu navegador)${NC}"

# 8. Esperar a que el servicio esté disponible
echo -e "${BLUE}⏳ Esperando a que el servicio esté disponible...${NC}"
sleep 5

# Verificar que el servicio existe
SERVICE_EXISTS=$(kubectl get svc devops-platform-service -n default 2>/dev/null)
if [ -z "$SERVICE_EXISTS" ]; then
    echo -e "${YELLOW}⚠️  El servicio devops-platform-service aún no existe.${NC}"
    echo -e "${YELLOW}   ArgoCD puede estar todavía desplegando los recursos.${NC}"
    echo -e "${BLUE}   Puedes verificar el estado en ArgoCD UI: https://localhost:8443${NC}"
else
    echo -e "${GREEN}📺 Abriendo tu aplicación en el navegador...${NC}"
    minikube service devops-platform-service -n default
fi

# 9. Información final
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 DevOps Platform Iniciado con Éxito 🎉       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📌 Recursos disponibles:${NC}"
echo -e "   • ArgoCD UI: ${GREEN}https://localhost:8443${NC}"
echo -e "   • Usuario: ${GREEN}admin${NC}"
if [ -n "$ARGOCD_PWD" ]; then
    echo -e "   • Password: ${GREEN}$ARGOCD_PWD${NC}"
fi
echo ""
echo -e "${BLUE}📝 Comandos útiles:${NC}"
echo -e "   • Ver pods: ${YELLOW}kubectl get pods -n default${NC}"
echo -e "   • Ver servicios: ${YELLOW}kubectl get svc -n default${NC}"
echo -e "   • Logs de ArgoCD: ${YELLOW}kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server${NC}"
echo -e "   • Acceder a la app: ${YELLOW}minikube service devops-platform-service -n default${NC}"
echo ""
echo -e "${YELLOW}⚠️  Para detener el port-forward de ArgoCD: ${NC}kill $ARGOCD_PID"
echo ""