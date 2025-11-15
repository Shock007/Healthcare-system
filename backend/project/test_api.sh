#!/bin/bash
# test_api.sh - Tests automatizados completos
# Sistema de Historia Clínica Distribuida - Versión Final

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

API_URL="${API_URL:-http://localhost:8000}"

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  🧪 TESTS AUTOMATIZADOS - Sistema Completo${NC}"
echo -e "${GREEN}================================================================${NC}\n"

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
    exit 1
}

# ==================== BÁSICOS ====================

run_test "API disponible"
if curl -s -f "$API_URL/" > /dev/null; then
    test_pass "API respondiendo"
else
    test_fail "API no disponible. Ejecuta: kubectl port-forward -n citus service/middleware-citus-service 8000:8000"
fi

run_test "Health check"
HEALTH=$(curl -s "$API_URL/health")
if echo "$HEALTH" | grep -q "saludable"; then
    test_pass "Sistema saludable"
else
    test_fail "Health check falló: $HEALTH"
fi

# ==================== AUTENTICACIÓN ====================

run_test "Login Admin"
ADMIN_TOKEN=$(curl -s -X POST "$API_URL/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$ADMIN_TOKEN" ]; then
    test_pass "Token admin obtenido"
else
    test_fail "No se pudo obtener token admin"
fi

run_test "Login Médico"
MEDICO_TOKEN=$(curl -s -X POST "$API_URL/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"dr_rodriguez","password":"password123"}' \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$MEDICO_TOKEN" ]; then
    test_pass "Token médico obtenido"
else
    test_fail "No se pudo obtener token médico"
fi

run_test "Login Paciente"
PACIENTE_TOKEN=$(curl -s -X POST "$API_URL/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"paciente_juan","password":"password123"}' \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$PACIENTE_TOKEN" ]; then
    test_pass "Token paciente obtenido"
else
    test_fail "No se pudo obtener token paciente"
fi

run_test "Login con credenciales inválidas"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrong"}')

if [ "$HTTP_CODE" = "401" ]; then
    test_pass "Credenciales inválidas rechazadas (401)"
else
    test_fail "Esperaba 401, obtuvo $HTTP_CODE"
fi

# ==================== ENDPOINT /me ====================

run_test "GET /me - Usuario actual"
ME_RESPONSE=$(curl -s "$API_URL/me" -H "Authorization: Bearer $ADMIN_TOKEN")
if echo "$ME_RESPONSE" | grep -q "admin"; then
    test_pass "Información de usuario obtenida"
else
    test_fail "No se pudo obtener info de usuario"
fi

# ==================== CRUD PACIENTES ====================

run_test "GET /pacientes - Listar pacientes (médico)"
PACIENTES=$(curl -s "$API_URL/pacientes?limit=5" \
  -H "Authorization: Bearer $MEDICO_TOKEN")

if echo "$PACIENTES" | grep -q "numero_documento"; then
    test_pass "Listado de pacientes obtenido"
else
    test_fail "No se pudo listar pacientes"
fi

run_test "GET /pacientes/{doc} - Obtener paciente específico"
PACIENTE=$(curl -s "$API_URL/pacientes/12345" \
  -H "Authorization: Bearer $MEDICO_TOKEN")

if echo "$PACIENTE" | grep -q "Juan"; then
    test_pass "Paciente 12345 obtenido"
else
    test_fail "No se pudo obtener paciente"
fi

run_test "POST /pacientes - Crear nuevo paciente"
NEW_PATIENT=$(curl -s -X POST "$API_URL/pacientes" \
  -H "Authorization: Bearer $MEDICO_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tipo_documento": "CC",
    "numero_documento": "99999",
    "primer_apellido": "Test",
    "primer_nombre": "Paciente",
    "fecha_nacimiento": "2000-01-01",
    "sexo": "M"
  }')

if echo "$NEW_PATIENT" | grep -q "99999"; then
    test_pass "Paciente creado exitosamente"

    run_test "PUT /pacientes/{doc} - Actualizar paciente"
    UPDATED=$(curl -s -X PUT "$API_URL/pacientes/99999" \
      -H "Authorization: Bearer $MEDICO_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"telefono": "3001234567"}')

    if echo "$UPDATED" | grep -q "3001234567"; then
        test_pass "Paciente actualizado"
    else
        test_fail "No se pudo actualizar paciente"
    fi
else
    test_fail "No se pudo crear paciente"
fi

# ==================== CONTROL DE ACCESO ====================

run_test "Paciente accediendo a su propia historia"
OWN_HISTORY=$(curl -s "$API_URL/pacientes/12345" \
  -H "Authorization: Bearer $PACIENTE_TOKEN")

if echo "$OWN_HISTORY" | grep -q "Juan"; then
    test_pass "Paciente puede ver su historia"
else
    test_fail "Paciente no puede ver su historia"
fi

run_test "Paciente intentando ver historia ajena"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/pacientes/67890" \
  -H "Authorization: Bearer $PACIENTE_TOKEN")

if [ "$HTTP_CODE" = "403" ]; then
    test_pass "Acceso denegado correctamente (403)"
else
    test_fail "Esperaba 403, obtuvo $HTTP_CODE"
fi

run_test "Admisionista intentando crear paciente"
ADMISIONISTA_TOKEN=$(curl -s -X POST "$API_URL/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"admisionista1","password":"password123"}' \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

ADMISIONISTA_CREATE=$(curl -s -X POST "$API_URL/pacientes" \
  -H "Authorization: Bearer $ADMISIONISTA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tipo_documento": "CC",
    "numero_documento": "88888",
    "primer_apellido": "Admision",
    "primer_nombre": "Test",
    "fecha_nacimiento": "1990-01-01",
    "sexo": "F"
  }')

if echo "$ADMISIONISTA_CREATE" | grep -q "88888"; then
    test_pass "Admisionista puede crear pacientes"
else
    test_fail "Admisionista no puede crear pacientes"
fi

# ==================== BÚSQUEDA ====================

run_test "GET /pacientes/buscar - Búsqueda por nombre"
SEARCH=$(curl -s "$API_URL/pacientes/buscar?nombre=Juan" \
  -H "Authorization: Bearer $MEDICO_TOKEN")

if echo "$SEARCH" | grep -q "Juan"; then
    test_pass "Búsqueda por nombre funcional"
else
    test_fail "Búsqueda no funciona"
fi

run_test "GET /pacientes/buscar - Búsqueda por documento"
SEARCH_DOC=$(curl -s "$API_URL/pacientes/buscar?documento=12345" \
  -H "Authorization: Bearer $MEDICO_TOKEN")

if echo "$SEARCH_DOC" | grep -q "12345"; then
    test_pass "Búsqueda por documento funcional"
else
    test_fail "Búsqueda por documento no funciona"
fi

# ==================== EXPORTACIÓN PDF ====================

run_test "GET /pacientes/{doc}/pdf - Exportar a PDF"
HTTP_CODE=$(curl -s -o /tmp/test_hc.pdf -w "%{http_code}" \
  "$API_URL/pacientes/12345/pdf" \
  -H "Authorization: Bearer $MEDICO_TOKEN")

if [ "$HTTP_CODE" = "200" ] && [ -f /tmp/test_hc.pdf ]; then
    FILE_SIZE=$(stat -f%z /tmp/test_hc.pdf 2>/dev/null || stat -c%s /tmp/test_hc.pdf 2>/dev/null)
    if [ "$FILE_SIZE" -gt 1000 ]; then
        test_pass "PDF generado exitosamente (${FILE_SIZE} bytes)"
        rm -f /tmp/test_hc.pdf
    else
        test_fail "PDF generado pero parece vacío"
    fi
else
    test_fail "No se pudo generar PDF (código: $HTTP_CODE)"
fi

# ==================== GESTIÓN DE USUARIOS (Admin) ====================

run_test "GET /usuarios - Listar usuarios (admin)"
USUARIOS=$(curl -s "$API_URL/usuarios" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if echo "$USUARIOS" | grep -q "admin"; then
    test_pass "Listado de usuarios obtenido"
else
    test_fail "No se pudo listar usuarios"
fi

run_test "POST /usuarios - Crear usuario (admin)"
NEW_USER=$(curl -s -X POST "$API_URL/usuarios" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test_user",
    "password": "test123",
    "rol": "medico",
    "nombres": "Usuario",
    "apellidos": "Prueba"
  }')

if echo "$NEW_USER" | grep -q "test_user"; then
    test_pass "Usuario creado exitosamente"
else
    test_fail "No se pudo crear usuario"
fi

run_test "Médico intentando crear usuario (debe fallar)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/usuarios" \
  -H "Authorization: Bearer $MEDICO_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"fail","password":"fail","rol":"medico"}')

if [ "$HTTP_CODE" = "403" ]; then
    test_pass "Acceso denegado correctamente (403)"
else
    test_fail "Médico no debería poder crear usuarios"
fi

# ==================== ESTADÍSTICAS ====================

run_test "GET /estadisticas - Estadísticas del sistema (admin)"
STATS=$(curl -s "$API_URL/estadisticas" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if echo "$STATS" | grep -q "total_pacientes"; then
    test_pass "Estadísticas obtenidas"
else
    test_fail "No se pudieron obtener estadísticas"
fi

# ==================== ENDPOINT SIN TOKEN ====================

run_test "Acceso sin token (debe retornar 401)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/pacientes")

if [ "$HTTP_CODE" = "401" ]; then
    test_pass "Endpoint protegido correctamente"
else
    test_fail "Esperaba 401, obtuvo $HTTP_CODE"
fi

# ==================== RESUMEN ====================

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}  ✓ TESTS COMPLETADOS${NC}"
echo -e "${GREEN}================================================================${NC}\n"

echo -e "${CYAN}Resumen:${NC}"
echo -e "  Total de tests: ${YELLOW}$test_counter${NC}"
echo -e "  Tests exitosos: ${GREEN}$pass_counter${NC}"
echo -e "  Tests fallidos: ${RED}$((test_counter - pass_counter))${NC}"

if [ $pass_counter -eq $test_counter ]; then
    echo -e "\n${GREEN}🎉 ¡TODOS LOS TESTS PASARON!${NC}"
    echo -e "${GREEN}Sistema completamente funcional${NC}\n"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Algunos tests fallaron${NC}\n"
    exit 1
fi
