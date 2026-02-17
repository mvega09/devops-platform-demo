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
    minikube start --driver=docker --memory=4096
    minikube addons enable metrics-server
else
    echo -e "${GREEN}✅ Minikube ya está en ejecución.${NC}"
    minikube addons enable metrics-server
fi

echo -e "${BLUE}🏗️  Configurando Sealed Secrets en el clúster...${NC}"
KUBESEAL_VERSION="0.21.0"

# Solo aplicamos el controlador al clúster de Minikube
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/controller.yaml

# Verificar que el deployment del controlador se cree
echo -e "${BLUE}⏳ Esperando al controlador de Sealed Secrets...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/sealed-secrets-controller -n kube-system

# 2. Inicializar y aplicar Terraform
echo -e "${BLUE}🏗️  Configurando infraestructura con Terraform...${NC}"
cd terraform

# Formatear código
terraform fmt

# Inicializar
echo -e "${BLUE}🔧 Inicializando Terraform...${NC}"
terraform init -upgrade

# Validar configuración
echo -e "${BLUE}🔍 Validando configuración de Terraform...${NC}"
terraform validate

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Configuración de Terraform inválida${NC}"
    exit 1
fi

# Aplicar TODO de una vez (sin -target para evitar warnings)
echo -e "${BLUE}🚀 Aplicando infraestructura completa...${NC}"
terraform apply -auto-approve

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Terraform aplicado con éxito.${NC}"
else
    echo -e "${RED}❌ Error en Terraform. Abortando.${NC}"
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

# Obtener credenciales de ArgoCD
echo -e "${BLUE}🔐 Obteniendo credenciales de ArgoCD...${NC}"
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [ -z "$ARGOCD_PWD" ]; then
    echo -e "${YELLOW}⚠️  No se pudo obtener la contraseña de ArgoCD automáticamente.${NC}"
else
    echo -e "${GREEN}✅ Credenciales de ArgoCD:${NC}"
    echo "   Usuario: admin"
    echo "   Password: $ARGOCD_PWD"
fi

# 4. Esperar a que la aplicación DevOps Platform esté sincronizada
echo -e "${BLUE}⏳ Esperando a que ArgoCD sincronice la aplicación...${NC}"
sleep 10

# Verificar que los pods de la aplicación estén listos
echo -e "${BLUE}⏳ Esperando a que los pods de la aplicación estén listos...${NC}"
kubectl wait --for=condition=ready --timeout=180s pod -l app=devops-platform -n default 2>/dev/null

# 5. Estado de la aplicación
echo -e "${BLUE}📊 Estado actual de los recursos de la App:${NC}"
kubectl get pods,svc -n default

# 6. Esperar a que Grafana y Prometheus estén listos
echo -e "${BLUE}⏳ Esperando a que Grafana y Prometheus estén listos...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/monitoring-grafana -n monitoring 2>/dev/null

# 7. Obtener credenciales de Grafana
echo -e "${BLUE}🔐 Obteniendo credenciales de Grafana...${NC}"
GRAFANA_PWD=$(kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode)

if [ -z "$GRAFANA_PWD" ]; then
    echo -e "${YELLOW}⚠️  No se pudo obtener la contraseña de Grafana. El servicio puede no estar listo aún.${NC}"
else
    echo -e "${GREEN}✅ Credenciales de Grafana:${NC}"
    echo "   Usuario: admin"
    echo "   Password: $GRAFANA_PWD"
fi

# 8. Lanzar port-forwards en segundo plano
echo -e "${GREEN}🌐 Configurando túneles para servicios...${NC}"

# Detener port-forwards previos
pkill -f "port-forward.*argocd-server" 2>/dev/null
pkill -f "port-forward.*monitoring-grafana" 2>/dev/null
pkill -f "port-forward.*prometheus-operated" 2>/dev/null

# App DevOps Platform
echo -e "${YELLOW}   → Iniciando túnel de la Aplicación...${NC}"
pkill -f "port-forward.*devops-platform-service" 2>/dev/null
kubectl port-forward svc/devops-platform-service -n default 8080:80 > /dev/null 2>&1 &
APP_PF_PID=$!
echo -e "${GREEN}   ✅ App URL: http://localhost:8080${NC}"

# ArgoCD
echo -e "${YELLOW}   → Iniciando túnel de ArgoCD...${NC}"
kubectl port-forward svc/argocd-server -n argocd 8443:443 > /dev/null 2>&1 &
ARGOCD_PID=$!
echo -e "${GREEN}   ✅ ArgoCD UI: https://localhost:8443${NC}"

# Grafana
echo -e "${YELLOW}   → Iniciando túnel de Grafana...${NC}"
kubectl port-forward svc/monitoring-grafana -n monitoring 3001:80 > /dev/null 2>&1 &
GRAFANA_PID=$!
echo -e "${GREEN}   ✅ Grafana UI: http://localhost:3001${NC}"

# Prometheus
echo -e "${YELLOW}   → Iniciando túnel de Prometheus...${NC}"
kubectl port-forward -n monitoring svc/prometheus-operated 9091:9090 > /dev/null 2>&1 &
PROMETHEUS_PID=$!
echo -e "${GREEN}   ✅ Prometheus UI: http://localhost:9091${NC}"

# 9. Esperar a que el servicio principal esté disponible
echo -e "${BLUE}⏳ Esperando a que el servicio principal esté disponible...${NC}"
sleep 5

# Verificar que el servicio existe
SERVICE_EXISTS=$(kubectl get svc devops-platform-service -n default 2>/dev/null)
if [ -z "$SERVICE_EXISTS" ]; then
    echo -e "${YELLOW}⚠️  El servicio devops-platform-service aún no existe.${NC}"
    echo -e "${YELLOW}   ArgoCD puede estar todavía desplegando los recursos.${NC}"
    echo -e "${BLUE}   Puedes verificar el estado en ArgoCD UI: https://localhost:8443${NC}"
else
    echo -e "${GREEN}📺 Abriendo tu aplicación en el navegador...${NC}"
    minikube service devops-platform-service -n default &
    APP_PID=$!
fi

# 10. Información final
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 DevOps Platform Iniciado con Éxito 🎉       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📌 Servicios Disponibles:${NC}"
echo ""
echo -e "${GREEN}🔹 ArgoCD (GitOps):${NC}"
echo -e "   • URL: ${GREEN}https://localhost:8443${NC}"
echo -e "   • Usuario: ${GREEN}admin${NC}"
if [ -n "$ARGOCD_PWD" ]; then
    echo -e "   • Password: ${GREEN}$ARGOCD_PWD${NC}"
fi
echo -e "   • PID: ${YELLOW}$ARGOCD_PID${NC}"
echo ""
echo -e "${GREEN}🔹 Grafana (Monitoreo):${NC}"
echo -e "   • URL: ${GREEN}http://localhost:3001${NC}"
echo -e "   • Usuario: ${GREEN}admin${NC}"
if [ -n "$GRAFANA_PWD" ]; then
    echo -e "   • Password: ${GREEN}$GRAFANA_PWD${NC}"
fi
echo -e "   • PID: ${YELLOW}$GRAFANA_PID${NC}"
echo ""
echo -e "${GREEN}🔹 Prometheus (Métricas):${NC}"
echo -e "   • URL: ${GREEN}http://localhost:9091${NC}"
echo -e "   • PID: ${YELLOW}$PROMETHEUS_PID${NC}"
echo ""
echo -e "${BLUE}📝 Comandos útiles:${NC}"
echo -e "   • Ver todos los pods: ${YELLOW}kubectl get pods -A${NC}"
echo -e "   • Ver pods de monitoreo: ${YELLOW}kubectl get pods -n monitoring${NC}"
echo -e "   • Ver servicios: ${YELLOW}kubectl get svc -A${NC}"
echo -e "   • Logs de ArgoCD: ${YELLOW}kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server${NC}"
echo -e "   • Logs de Grafana: ${YELLOW}kubectl logs -n monitoring -l app.kubernetes.io/name=grafana${NC}"
echo ""
echo -e "${YELLOW}⚠️  Para detener los port-forwards:${NC}"
echo -e "   kill $ARGOCD_PID $GRAFANA_PID $PROMETHEUS_PID"
echo ""
echo -e "${BLUE}💡 Tip: Usa 'pkill -f port-forward' para detener todos los túneles${NC}"
echo ""

# Guardar PIDs en un archivo para facilitar limpieza posterior
echo "$ARGOCD_PID" > /tmp/devops-platform-pids.txt
echo "$GRAFANA_PID" >> /tmp/devops-platform-pids.txt
echo "$PROMETHEUS_PID" >> /tmp/devops-platform-pids.txt
[ -n "$APP_PID" ] && echo "$APP_PID" >> /tmp/devops-platform-pids.txt

echo -e "${GREEN}✅ PIDs guardados en /tmp/devops-platform-pids.txt${NC}"
echo ""