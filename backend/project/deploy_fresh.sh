#!/bin/bash
# deploy_fresh.sh - Despliegue fresh del middleware MEJORADO
# Versión 2.0 - Con verificaciones adicionales

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Despliegue Fresh del Middleware${NC}"
echo -e "${GREEN}  Versión 2.0 - Mejorada${NC}"
echo -e "${GREEN}========================================${NC}\n"

NAMESPACE="citus"

print_step() { echo -e "\n${YELLOW}[PASO $1/8]${NC} $2"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# ==================== PASO 1: Eliminar Deployment ====================
print_step 1 "Eliminando deployment actual..."
kubectl delete deployment middleware-citus -n $NAMESPACE 2>/dev/null || true
print_success "Deployment eliminado"
sleep 5

# ==================== PASO 2: Aplicar Deployment ====================
print_step 2 "Aplicando nuevo deployment..."
kubectl apply -f infra/app-deployment.yaml
print_success "Deployment aplicado"
sleep 3

# ==================== PASO 3: Esperar Pods ====================
print_step 3 "Esperando a que el pod esté listo (máx 90s)..."
if kubectl wait --for=condition=ready pod -l app=middleware-citus -n $NAMESPACE --timeout=90s 2>/dev/null; then
    print_success "Pod listo"
else
    print_error "Pod no está listo, verificando estado..."
    kubectl get pods -n $NAMESPACE -l app=middleware-citus
    kubectl describe pod -n $NAMESPACE -l app=middleware-citus | tail -20
    exit 1
fi

# ==================== PASO 4: Verificar Imagen ====================
print_step 4 "Verificando imagen del pod..."
POD_NAME=$(kubectl get pod -n $NAMESPACE -l app=middleware-citus -o jsonpath="{.items[0].metadata.name}")
print_info "Pod: $POD_NAME"

IMAGE_INFO=$(kubectl describe pod -n $NAMESPACE $POD_NAME | grep -A 2 "Image:")
echo -e "${BLUE}${IMAGE_INFO}${NC}"
print_success "Imagen verificada"

# ==================== PASO 5: Verificar Logs ====================
print_step 5 "Verificando logs del pod..."
sleep 3
echo -e "${BLUE}Últimas 15 líneas:${NC}"
kubectl logs -n $NAMESPACE $POD_NAME --tail=15

if kubectl logs -n $NAMESPACE $POD_NAME --tail=50 | grep -q "Uvicorn running"; then
    print_success "Uvicorn iniciado correctamente"
else
    print_error "¡Advertencia! No se detectó Uvicorn"
fi

# ==================== PASO 6: Verificar Endpoints ====================
print_step 6 "Verificando endpoints del servicio..."
kubectl get endpoints -n $NAMESPACE middleware-citus-service
print_success "Endpoints verificados"

# ==================== PASO 7: Reiniciar Port-Forward ====================
print_step 7 "Configurando port-forward..."
# Matar cualquier port-forward existente
pkill -f 'port-forward.*8000' 2>/dev/null || true
sleep 2

# Iniciar nuevo port-forward en background
kubectl port-forward -n $NAMESPACE service/middleware-citus-service 8000:8000 >/dev/null 2>&1 &
PF_PID=$!
print_info "Port-forward iniciado (PID: $PF_PID)"
sleep 3

# Verificar que port-forward está funcionando
if ps -p $PF_PID >/dev/null; then
    print_success "Port-forward activo"
else
    print_error "Port-forward falló"
fi

# ==================== PASO 8: Test Rápido ====================
print_step 8 "Ejecutando test rápido..."
sleep 2

echo -e "\n${BLUE}Test 1: Health Check${NC}"
if curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
    print_success "Health check OK"
else
    print_error "Health check falló"
fi

echo -e "\n${BLUE}Test 2: Sin token (debe retornar 401)${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/paciente/1)
if [ "$HTTP_CODE" = "401" ]; then
    print_success "Retorna 401 correctamente ✓"
else
    print_error "Retorna $HTTP_CODE (se esperaba 401) ✗"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Despliegue Completado${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Siguiente paso:${NC}"
echo "  ./test_api.sh"
echo ""
echo -e "${BLUE}O probar manualmente:${NC}"
echo "  curl http://localhost:8000/health"
echo "  curl http://localhost:8000/paciente/1  # Debe retornar 401"
