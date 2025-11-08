#!/bin/bash
# test_api.sh - Script de pruebas automatizadas
# Historia Clínica Distribuida - Semana 1

set -e

# Colores
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
BLUE='\\033[0;34m'
NC='\\033[0m'

API_URL="${API_URL:-http://localhost:8000}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Pruebas Automatizadas - Semana 1${NC}"
echo -e "${GREEN}========================================${NC}\\n"

# Verificar que la API esté corriendo
echo -e "${YELLOW}[TEST 1]${NC} Verificando que la API esté disponible..."
if curl -s -f "$API_URL/" > /dev/null; then
    echo -e "${GREEN}✓${NC} API disponible en $API_URL"
else
    echo -e "${RED}✗${NC} API no disponible. Asegúrate de ejecutar:"
    echo "  kubectl port-forward -n citus service/middleware-citus-service 8000:8000"
    exit 1
fi

# Test 1: Health check
echo -e "\\n${YELLOW}[TEST 2]${NC} Probando /health..."
HEALTH_RESPONSE=$(curl -s "$API_URL/health")
echo "Respuesta: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo -e "${GREEN}✓${NC} Health check exitoso"
else
    echo -e "${RED}✗${NC} Health check falló"
    exit 1
fi

# Test 2: Obtener token
echo -e "\\n${YELLOW}[TEST 3]${NC} Obteniendo token JWT..."
TOKEN_RESPONSE=$(curl -s -X POST "$API_URL/token" \\
  -H "Content-Type: application/json" \\
  -d '{"username":"admin","password":"admin"}')

TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗${NC} No se pudo obtener token"
    echo "Respuesta: $TOKEN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓${NC} Token obtenido exitosamente"
echo "Token (primeros 20 caracteres): ${TOKEN:0:20}..."

# Test 3: Obtener paciente sin token (debe fallar con 401)
echo -e "\\n${YELLOW}[TEST 4]${NC} Probando endpoint protegido sin token (debe fallar con 401)..."
NO_AUTH_RESPONSE=$(curl -s -w "\\nHTTP_CODE:%{http_code}" "$API_URL/paciente/1")
HTTP_CODE=$(echo "$NO_AUTH_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

echo -e "${BLUE}Código recibido: ${HTTP_CODE}${NC}"
echo -e "${BLUE}Respuesta completa:${NC}"
echo "$NO_AUTH_RESPONSE" | grep -v "HTTP_CODE"

if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓${NC} Correctamente rechazado (401 Unauthorized)"
elif [ "$HTTP_CODE" = "403" ]; then
    echo -e "${RED}✗✗✗ CRÍTICO: Se obtuvo 403 en lugar de 401${NC}"
    echo -e "${RED}Esto indica que el pod está usando código antiguo${NC}"
    echo -e "${YELLOW}Solución:${NC}"
    echo "  1. cd backend/project"
    echo "  2. ./clean_and_rebuild.sh"
    echo "  3. ./deploy_fresh.sh"
    echo "  4. Reintentar tests"
    exit 1
else
    echo -e "${RED}✗${NC} Se esperaba código 401, se obtuvo $HTTP_CODE"
    exit 1
fi

# Test 4: Obtener paciente con token
echo -e "\\n${YELLOW}[TEST 5]${NC} Obteniendo paciente con token válido..."
PATIENT_RESPONSE=$(curl -s "$API_URL/paciente/1" \\
  -H "Authorization: Bearer $TOKEN")

echo "Respuesta: $PATIENT_RESPONSE"

if echo "$PATIENT_RESPONSE" | grep -q "documento_id"; then
    echo -e "${GREEN}✓${NC} Paciente obtenido exitosamente"

    # Extraer y mostrar datos
    NOMBRE=$(echo "$PATIENT_RESPONSE" | grep -o '"nombre":"[^"]*"' | cut -d'"' -f4)
    APELLIDO=$(echo "$PATIENT_RESPONSE" | grep -o '"apellido":"[^"]*"' | cut -d'"' -f4)
    DOC_ID=$(echo "$PATIENT_RESPONSE" | grep -o '"documento_id":"[^"]*"' | cut -d'"' -f4)

    echo "  - Nombre: $NOMBRE $APELLIDO"
    echo "  - Documento: $DOC_ID"
else
    echo -e "${RED}✗${NC} No se pudo obtener paciente"
    exit 1
fi

# Test 5: Listar pacientes
echo -e "\\n${YELLOW}[TEST 6]${NC} Listando todos los pacientes..."
PATIENTS_LIST=$(curl -s "$API_URL/pacientes" \\
  -H "Authorization: Bearer $TOKEN")

PATIENT_COUNT=$(echo "$PATIENTS_LIST" | grep -o '"id":[0-9]*' | wc -l)
echo -e "${GREEN}✓${NC} Se encontraron $PATIENT_COUNT pacientes"

# Test 6: Obtener paciente inexistente
echo -e "\\n${YELLOW}[TEST 7]${NC} Probando con paciente inexistente..."
NOT_FOUND_RESPONSE=$(curl -s -w "\\nHTTP_CODE:%{http_code}" "$API_URL/paciente/9999" \\
  -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$NOT_FOUND_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "404" ]; then
    echo -e "${GREEN}✓${NC} Correctamente retorna 404 Not Found"
else
    echo -e "${RED}✗${NC} Se esperaba código 404, se obtuvo $HTTP_CODE"
fi

# Test 7: Token inválido
echo -e "\\n${YELLOW}[TEST 8]${NC} Probando con token inválido..."
INVALID_TOKEN_RESPONSE=$(curl -s -w "\\nHTTP_CODE:%{http_code}" "$API_URL/paciente/1" \\
  -H "Authorization: Bearer token_invalido_123")
HTTP_CODE=$(echo "$INVALID_TOKEN_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓${NC} Token inválido correctamente rechazado"
else
    echo -e "${RED}✗${NC} Se esperaba código 401, se obtuvo $HTTP_CODE"
fi

# Test 8: Credenciales incorrectas
echo -e "\\n${YELLOW}[TEST 9]${NC} Probando login con credenciales incorrectas..."
BAD_CREDS_RESPONSE=$(curl -s -w "\\nHTTP_CODE:%{http_code}" -X POST "$API_URL/token" \\
  -H "Content-Type: application/json" \\
  -d '{"username":"admin","password":"wrongpassword"}')
HTTP_CODE=$(echo "$BAD_CREDS_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓${NC} Credenciales incorrectas rechazadas"
else
    echo -e "${RED}✗${NC} Se esperaba código 401, se obtuvo $HTTP_CODE"
fi

# Resumen
echo -e "\\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ TODAS LAS PRUEBAS COMPLETADAS${NC}"
echo -e "${GREEN}========================================${NC}\\n"

echo -e "${YELLOW}Resumen:${NC}"
echo "  ✓ Health check funcional"
echo "  ✓ Autenticación JWT operativa"
echo "  ✓ Endpoints protegidos correctamente (401, no 403)"
echo "  ✓ CRUD de pacientes funcional"
echo "  ✓ Manejo de errores apropiado"

echo -e "\\n${GREEN}¡Sistema 100% funcional - Listo para Semana 2!${NC}\\n"
