#!/bin/bash

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}🗑️  Iniciando destrucción de DevOps Platform...${NC}"
echo ""

# Confirmación de seguridad
read -p "$(echo -e ${YELLOW}¿Estás seguro de que quieres destruir toda la infraestructura? \(y/n\): ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Operación cancelada.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}1️⃣  Deteniendo todos los port-forwards activos...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Detener port-forwards usando el archivo de PIDs si existe
if [ -f /tmp/devops-platform-pids.txt ]; then
    echo -e "${YELLOW}   → Deteniendo procesos registrados...${NC}"
    while read pid; do
        if kill $pid 2>/dev/null; then
            echo -e "${GREEN}   ✅ Proceso $pid detenido${NC}"
        fi
    done < /tmp/devops-platform-pids.txt
    rm /tmp/devops-platform-pids.txt
    echo -e "${GREEN}   ✅ Archivo de PIDs eliminado${NC}"
fi

# Detener todos los port-forwards conocidos
echo -e "${YELLOW}   → Deteniendo port-forwards específicos...${NC}"
pkill -f "port-forward.*argocd-server" 2>/dev/null && echo -e "${GREEN}   ✅ ArgoCD port-forward detenido${NC}"
pkill -f "port-forward.*monitoring-grafana" 2>/dev/null && echo -e "${GREEN}   ✅ Grafana port-forward detenido${NC}"
pkill -f "port-forward.*prometheus-operated" 2>/dev/null && echo -e "${GREEN}   ✅ Prometheus port-forward detenido${NC}"

# Detener cualquier otro port-forward
pkill -f "kubectl.*port-forward" 2>/dev/null

# Detener minikube service si está corriendo
pkill -f "minikube service" 2>/dev/null && echo -e "${GREEN}   ✅ Minikube service detenido${NC}"

echo -e "${GREEN}   ✅ Todos los port-forwards detenidos${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}2️⃣  Eliminando recursos de Kubernetes manualmente...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Eliminar la aplicación de ArgoCD
echo -e "${YELLOW}   → Eliminando Application de ArgoCD...${NC}"
kubectl delete application devops-platform -n argocd --timeout=60s 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Application de ArgoCD eliminada${NC}"
else
    echo -e "${YELLOW}   ⚠️  Application no existe o ya fue eliminada${NC}"
fi

# Eliminar recursos en el namespace default
echo -e "${YELLOW}   → Eliminando recursos de la aplicación en default...${NC}"
kubectl delete all -l app=devops-platform -n default --timeout=60s 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Recursos de la aplicación eliminados${NC}"
else
    echo -e "${YELLOW}   ⚠️  No hay recursos de la aplicación${NC}"
fi

# Eliminar namespace de monitoring (Grafana y Prometheus)
echo -e "${YELLOW}   → Eliminando namespace de monitoring...${NC}"
kubectl delete namespace monitoring --timeout=120s 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Namespace monitoring eliminado${NC}"
else
    echo -e "${YELLOW}   ⚠️  Namespace monitoring no existe${NC}"
fi

# Eliminar namespace de ArgoCD
echo -e "${YELLOW}   → Eliminando namespace de ArgoCD...${NC}"
kubectl delete namespace argocd --timeout=120s 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Namespace argocd eliminado${NC}"
else
    echo -e "${YELLOW}   ⚠️  Namespace argocd no existe${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}3️⃣  Destruyendo infraestructura con Terraform...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd terraform

# Verificar si Terraform está inicializado
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}   ⚠️  Terraform no está inicializado. Inicializando...${NC}"
    terraform init
fi

# Destruir recursos de Terraform
echo -e "${YELLOW}   → Ejecutando terraform destroy...${NC}"
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Terraform destroy exitoso${NC}"
else
    echo -e "${RED}   ❌ Error en terraform destroy${NC}"
    echo -e "${YELLOW}   ⚠️  Continuando con limpieza...${NC}"
fi

# Limpiar archivos de estado de Terraform (opcional pero recomendado)
echo -e "${YELLOW}   → ¿Deseas limpiar el estado de Terraform? (y/n): ${NC}"
read -n 1 -r CLEAN_TF_STATE
echo
if [[ "$CLEAN_TF_STATE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}   → Limpiando archivos de Terraform...${NC}"
    rm -rf .terraform terraform.tfstate* .terraform.lock.hcl
    echo -e "${GREEN}   ✅ Archivos de Terraform eliminados${NC}"
fi

cd ..

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}4️⃣  Verificando estado final...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}   → Namespaces restantes:${NC}"
kubectl get namespaces | grep -E "argocd|monitoring|default" || echo -e "${GREEN}   ✅ Namespaces limpiados${NC}"

echo -e "${YELLOW}   → Pods en todos los namespaces:${NC}"
REMAINING_PODS=$(kubectl get pods --all-namespaces 2>/dev/null | grep -E "argocd|monitoring|devops-platform" | wc -l)
if [ "$REMAINING_PODS" -eq 0 ]; then
    echo -e "${GREEN}   ✅ No hay pods relacionados con DevOps Platform${NC}"
else
    echo -e "${YELLOW}   ⚠️  Aún hay $REMAINING_PODS pod(s) relacionados${NC}"
    kubectl get pods --all-namespaces | grep -E "argocd|monitoring|devops-platform"
fi

echo -e "${YELLOW}   → Port-forwards activos:${NC}"
ACTIVE_PF=$(ps aux | grep -E "port-forward.*(argocd|grafana|prometheus)" | grep -v grep | wc -l)
if [ "$ACTIVE_PF" -eq 0 ]; then
    echo -e "${GREEN}   ✅ No hay port-forwards activos${NC}"
else
    echo -e "${YELLOW}   ⚠️  Aún hay $ACTIVE_PF port-forward(s) activos${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}5️⃣  Gestión de Minikube...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}¿Qué deseas hacer con Minikube?${NC}"
echo "  1) Dejarlo corriendo"
echo "  2) Detenerlo (minikube stop)"
echo "  3) Eliminarlo completamente (minikube delete)"
read -p "Selecciona una opción (1/2/3): " -n 1 -r MINIKUBE_OPTION
echo

case $MINIKUBE_OPTION in
    1)
        echo -e "${GREEN}✅ Minikube seguirá en ejecución${NC}"
        ;;
    2)
        echo -e "${BLUE}🛑 Deteniendo Minikube...${NC}"
        minikube stop
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Minikube detenido${NC}"
        else
            echo -e "${RED}❌ Error al detener Minikube${NC}"
        fi
        ;;
    3)
        echo -e "${RED}🗑️  Eliminando Minikube completamente...${NC}"
        minikube delete
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Minikube eliminado${NC}"
        else
            echo -e "${RED}❌ Error al eliminar Minikube${NC}"
        fi
        ;;
    *)
        echo -e "${YELLOW}⚠️  Opción inválida. Minikube seguirá en ejecución${NC}"
        ;;
esac

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ DevOps Platform Destruido con Éxito ✅        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📋 Resumen de acciones realizadas:${NC}"
echo -e "   ${GREEN}✓${NC} Port-forwards detenidos (ArgoCD, Grafana, Prometheus)"
echo -e "   ${GREEN}✓${NC} Recursos de Kubernetes eliminados"
echo -e "   ${GREEN}✓${NC} Namespaces limpiados (argocd, monitoring)"
echo -e "   ${GREEN}✓${NC} Estado de Terraform destruido"
echo ""
echo -e "${BLUE}📝 Comandos útiles para verificar:${NC}"
echo -e "   • Ver namespaces: ${YELLOW}kubectl get namespaces${NC}"
echo -e "   • Ver todos los pods: ${YELLOW}kubectl get pods --all-namespaces${NC}"
echo -e "   • Estado de Minikube: ${YELLOW}minikube status${NC}"
echo -e "   • Port-forwards activos: ${YELLOW}ps aux | grep port-forward${NC}"
echo ""
echo -e "${YELLOW}💡 Para volver a desplegar: ${NC}./deploy-tf.sh"
echo ""

# Limpiar archivos temporales de logs si existen
rm -f /tmp/argocd-portforward.log /tmp/grafana-portforward.log /tmp/prometheus-portforward.log 2>/dev/null