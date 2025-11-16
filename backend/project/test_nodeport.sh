#!/bin/bash
# ==============================================================================
# test_nodeport.sh - Tests de Conectividad NodePort
# ==============================================================================
# Verifica que el sistema sea accesible desde la red local
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

NAMESPACE="citus"
MINIKUBE_IP=$(minikube ip)
NODE_PORT=$(kubectl get svc middleware-citus-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
BASE_URL="http://${MINIKUBE_IP}:${NODE_PORT}"

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  🧪 TESTS DE CONECTIVIDAD NODEPORT${NC}"
echo -e "${GREEN}================================================================${NC}\n"

echo -e "${CYAN}Configuración:${NC}"
echo -e "  IP Minikube:  ${YELLOW}${MINIKUBE_IP}${NC}"
echo -e "  NodePort:     ${YELLOW}${NODE_PORT}${NC}"
echo -e "  Base URL:     ${YELLOW}${BASE_URL}${NC}"
echo -e ""

test_counter=0
pass_counter=0

run_test() {
    ((test_counter++))
    echo -e "\n${CYAN}[TEST $test_counter]${NC} $1"
}

test_pass() {
    ((pass_counter++))
    echo -e "${GREEN}✓ PASS${NC} - $1"
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC} - $1"
}

# ==================== TEST 1: Conectividad Básica ====================
run_test "Conectividad TCP al puerto"
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${MINIKUBE_IP}/${NODE_PORT}"; then
    test_pass "Puerto ${NODE_PORT} accesible"
else
    test_fail "No se puede conectar al puerto ${NODE_PORT}"
    echo -e "${YELLOW}Sugerencia:${NC} Verifica que Minikube esté corriendo y el servicio desplegado"
    exit 1
fi

# ==================== TEST 2: Root Endpoint ====================
run_test "Root endpoint (/)"
RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    test_pass "Root endpoint responde (HTTP $HTTP_CODE)"
    if echo "$BODY" | grep -q "Historia Clínica"; then
        test_pass "Respuesta contiene información esperada"
    fi
else
    test_fail "Root endpoint falló (HTTP $HTTP_CODE)"
fi

# ==================== TEST 3: Health Check ====================
run_test "Health check (/health)"
HEALTH_RESPONSE=$(curl -s "${BASE_URL}/health")

if echo "$HEALTH_RESPONSE" | grep -q "saludable"; then
    test_pass "Sistema saludable"
    echo -e "${CYAN}Estado:${NC}"
    echo "$HEALTH_RESPONSE" | grep -o '"estado":"[^"]*"' | cut -d'"' -f4
else
    test_fail "Health check no responde correctamente"
fi

# ==================== TEST 4: Swagger UI ====================
run_test "Swagger UI (/docs)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/docs")

if [ "$HTTP_CODE" = "200" ]; then
    test_pass "Swagger UI accesible (HTTP $HTTP_CODE)"
else
    test_fail "Swagger UI no accesible (HTTP $HTTP_CODE)"
fi

# ==================== TEST 5: OpenAPI Schema ====================
run_test "OpenAPI Schema (/openapi.json)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/openapi.json")

if [ "$HTTP_CODE" = "200" ]; then
    test_pass "OpenAPI schema disponible"
else
    test_fail "OpenAPI schema no disponible"
fi

# ==================== TEST 6: Autenticación ====================
run_test "Sistema de autenticación (/token)"
TOKEN_RESPONSE=$(curl -s -X POST "${BASE_URL}/token" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin"}')

if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
    test_pass "Autenticación funcional"
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    echo -e "${CYAN}Token obtenido:${NC} ${TOKEN:0:50}..."
else
    test_fail "No se pudo obtener token"
    echo "$TOKEN_RESPONSE"
fi

# ==================== TEST 7: Endpoint Protegido ====================
if [ -n "$TOKEN" ]; then
    run_test "Acceso con token (/me)"
    ME_RESPONSE=$(curl -s "${BASE_URL}/me" -H "Authorization: Bearer $TOKEN")

    if echo "$ME_RESPONSE" | grep -q "admin"; then
        test_pass "Endpoint protegido accesible con token válido"
    else
        test_fail "No se pudo acceder con token"
    fi

    run_test "Listar pacientes (/pacientes)"
    PACIENTES=$(curl -s "${BASE_URL}/pacientes?limit=3" \
        -H "Authorization: Bearer $TOKEN")

    if echo "$PACIENTES" | grep -q "numero_documento"; then
        test_pass "Listado de pacientes funcional"
    else
        test_fail "No se pudo listar pacientes"
    fi
fi

# ==================== TEST 8: Acceso sin Token ====================
run_test "Protección de endpoints (sin token)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/pacientes")

if [ "$HTTP_CODE" = "401" ]; then
    test_pass "Endpoints protegidos correctamente (HTTP 401)"
else
    test_fail "Endpoint debería requerir autenticación"
fi

# ==================== TEST 9: CORS (si aplica) ====================
run_test "Verificación de headers"
HEADERS=$(curl -s -I "${BASE_URL}/")

if echo "$HEADERS" | grep -q "HTTP"; then
    test_pass "Headers HTTP correctos"
else
    test_fail "Headers no válidos"
fi

# ==================== TEST 10: Rendimiento ====================
run_test "Test de rendimiento (latencia)"
START=$(date +%s%N)
curl -s "${BASE_URL}/health" > /dev/null
END=$(date +%s%N)
LATENCY=$((($END - $START) / 1000000))

if [ $LATENCY -lt 1000 ]; then
    test_pass "Latencia: ${LATENCY}ms (excelente)"
elif [ $LATENCY -lt 2000 ]; then
    test_pass "Latencia: ${LATENCY}ms (buena)"
else
    echo -e "${YELLOW}⚠${NC} Latencia: ${LATENCY}ms (alta)"
fi

# ==================== RESUMEN ====================
echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}  📊 RESUMEN DE TESTS${NC}"
echo -e "${GREEN}================================================================${NC}\n"

echo -e "${CYAN}Total de tests:${NC}     ${YELLOW}$test_counter${NC}"
echo -e "${CYAN}Tests exitosos:${NC}     ${GREEN}$pass_counter${NC}"
echo -e "${CYAN}Tests fallidos:${NC}     ${RED}$((test_counter - pass_counter))${NC}"

if [ $pass_counter -eq $test_counter ]; then
    echo -e "\n${GREEN}✓ TODOS LOS TESTS PASARON${NC}"
    echo -e "${GREEN}Sistema completamente funcional desde red local${NC}\n"

    echo -e "${CYAN}Compartir estas URLs con tu equipo:${NC}"
    echo -e "  ${YELLOW}${BASE_URL}/docs${NC}  (Swagger UI)"
    echo -e "  ${YELLOW}${BASE_URL}/redoc${NC} (ReDoc)"
    echo -e ""
    exit 0
else
    echo -e "\n${YELLOW}⚠ ALGUNOS TESTS FALLARON${NC}"
    echo -e "${YELLOW}Revisa los logs arriba para más detalles${NC}\n"
    exit 1
fi
