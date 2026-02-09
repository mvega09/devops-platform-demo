#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🛑 Deteniendo todos los port-forwards...${NC}"

# Opción 1: Usando el archivo de PIDs
if [ -f /tmp/devops-platform-pids.txt ]; then
    while read pid; do
        kill $pid 2>/dev/null && echo -e "${GREEN}✅ Proceso $pid detenido${NC}"
    done < /tmp/devops-platform-pids.txt
    rm /tmp/devops-platform-pids.txt
fi

# Opción 2: Matar todos los port-forward
pkill -f "port-forward"

echo -e "${GREEN}✅ Todos los túneles detenidos${NC}"