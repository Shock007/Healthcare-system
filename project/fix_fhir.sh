#!/bin/bash
# fix_fhir.sh - Arregla la integración FHIR
# Ejecutar desde la raíz del repositorio

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Arreglando Integración FHIR${NC}"
echo -e "${GREEN}========================================${NC}\n"

NAMESPACE="citus"

# 1. Verificar columna fhir_id
echo -e "${YELLOW}[1/5]${NC} Verificando columna fhir_id..."
COORDINATOR_POD=$(kubectl get pod -n $NAMESPACE -l app=citus-coordinator -o jsonpath="{.items[0].metadata.name}")

HAS_FHIR_ID=$(kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica -t -c \
  "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='pacientes' AND column_name='fhir_id';")

if [ "$HAS_FHIR_ID" -eq 0 ]; then
    echo "  → Agregando columna fhir_id..."
    kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica <<'EOF'
ALTER TABLE public.pacientes ADD COLUMN fhir_id VARCHAR(100) UNIQUE;
CREATE INDEX idx_pacientes_fhir_id ON public.pacientes(fhir_id);
EOF
    echo -e "${GREEN}  ✓${NC} Columna fhir_id agregada"
else
    echo -e "${GREEN}  ✓${NC} Columna fhir_id ya existe"
fi

# 2. Reconstruir imagen Docker
echo -e "\n${YELLOW}[2/5]${NC} Reconstruyendo imagen Docker..."
cd project
docker build -t middleware-citus:1.0 --no-cache . 2>&1 | tail -10
cd ..
echo -e "${GREEN}  ✓${NC} Imagen reconstruida"

# 3. Cargar en Minikube
echo -e "\n${YELLOW}[3/5]${NC} Cargando imagen en Minikube..."
minikube image load middleware-citus:1.0
echo -e "${GREEN}  ✓${NC} Imagen cargada"

# 4. Reiniciar pod
echo -e "\n${YELLOW}[4/5]${NC} Reiniciando middleware..."
kubectl delete pod -n $NAMESPACE -l app=middleware-citus
echo "  Esperando a que el pod esté listo..."
kubectl wait --for=condition=ready pod -l app=middleware-citus -n $NAMESPACE --timeout=120s
echo -e "${GREEN}  ✓${NC} Middleware reiniciado"

# 5. Verificar
echo -e "\n${YELLOW}[5/5]${NC} Verificando integración..."

# Matar port-forward anterior
pkill -f "port-forward.*8000" 2>/dev/null || true
sleep 2

# Nuevo port-forward
kubectl port-forward -n $NAMESPACE service/middleware-citus-service 8000:8000 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 5

# Health check
echo "  → Probando health check..."
HEALTH=$(curl -s http://localhost:8000/health)

if echo "$HEALTH" | grep -q "fhir_server"; then
    echo -e "${GREEN}  ✓${NC} Health check incluye FHIR"
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
else
    echo -e "${RED}  ✗${NC} Health check NO incluye FHIR"
    echo "Respuesta: $HEALTH"
    kill $PORT_FORWARD_PID 2>/dev/null
    exit 1
fi

# Probar endpoint POST /pacientes
echo -e "\n  → Probando endpoint POST /pacientes..."
TOKEN=$(curl -s -X POST http://localhost:8000/token \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

TEST_CREATE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:8000/pacientes \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"documento_id":"TEST999","nombre":"Test","apellido":"FHIR","genero":"M"}')

HTTP_CODE=$(echo "$TEST_CREATE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}  ✓${NC} Endpoint POST /pacientes funciona"
else
    echo -e "${RED}  ✗${NC} Endpoint POST /pacientes falló (HTTP $HTTP_CODE)"
    kill $PORT_FORWARD_PID 2>/dev/null
    exit 1
fi

# Limpiar
kill $PORT_FORWARD_PID 2>/dev/null

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ FHIR ARREGLADO EXITOSAMENTE${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Próximos pasos:${NC}"
echo "1. Hacer port-forward:"
echo "   kubectl port-forward -n citus service/middleware-citus-service 8000:8000 &"
echo ""
echo "2. Ejecutar tests:"
echo "   ./project/test_fhir.sh"
echo ""
echo "3. Ver Swagger UI:"
echo "   http://localhost:8000/docs"
echo ""
echo -e "${GREEN}¡Listo!${NC}\n"
