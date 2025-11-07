#!/bin/bash
# upgrade_to_fhir.sh - Script para actualizar el sistema existente con FHIR
# Ejecutar después de tener el sistema base funcionando

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Actualización FHIR${NC}"
echo -e "${GREEN}  Agregando integración HAPI FHIR${NC}"
echo -e "${GREEN}========================================${NC}\n"

print_step() { echo -e "\n${YELLOW}[PASO $1]${NC} $2"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

NAMESPACE="citus"

# Detectar directorio
if [ -f "citus-deployment.yaml" ]; then
    PROJECT_DIR="."
elif [ -f "project/citus-deployment.yaml" ]; then
    PROJECT_DIR="project"
else
    echo -e "${RED}Error: No se encuentra citus-deployment.yaml${NC}"
    exit 1
fi

# ==================== PASO 1: Actualizar base de datos ====================
print_step 1 "Actualizando esquema de base de datos..."

COORDINATOR_POD=$(kubectl get pod -n $NAMESPACE -l app=citus-coordinator -o jsonpath="{.items[0].metadata.name}")

echo "Agregando columna fhir_id..."
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica <<EOF
ALTER TABLE public.pacientes
ADD COLUMN IF NOT EXISTS fhir_id VARCHAR(100) UNIQUE;

CREATE INDEX IF NOT EXISTS idx_pacientes_fhir_id
ON public.pacientes(fhir_id);

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'pacientes' AND table_schema = 'public';
EOF

print_success "Esquema actualizado"

# ==================== PASO 2: Reconstruir imagen Docker ====================
print_step 2 "Reconstruyendo imagen Docker con dependencias FHIR..."

if [ "$PROJECT_DIR" != "." ]; then cd $PROJECT_DIR; fi
docker build -t middleware-citus:2.0 .
if [ "$PROJECT_DIR" != "." ]; then cd ..; fi

print_success "Imagen construida"

minikube image load middleware-citus:2.0
print_success "Imagen cargada en Minikube"

# ==================== PASO 3: Actualizar deployment ====================
print_step 3 "Actualizando deployment..."

# Actualizar la imagen en el deployment
kubectl set image deployment/middleware-citus -n $NAMESPACE middleware=middleware-citus:2.0

echo "Esperando rollout..."
kubectl rollout status deployment/middleware-citus -n $NAMESPACE

print_success "Deployment actualizado"

# ==================== PASO 4: Verificación ====================
print_step 4 "Verificando integración FHIR..."

echo -e "\n${YELLOW}Esperando a que el pod esté listo...${NC}"
sleep 10

echo -e "\n${YELLOW}Estado de los pods:${NC}"
kubectl get pods -n $NAMESPACE

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ ACTUALIZACIÓN COMPLETA${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Nuevos endpoints FHIR disponibles:${NC}"
echo "  POST   /pacientes/{id}/sync-to-fhir  - Sincronizar paciente a FHIR"
echo "  GET    /fhir/patient/{fhir_id}       - Obtener paciente de FHIR"
echo "  GET    /fhir/search                  - Buscar en FHIR"
echo "  POST   /fhir/import/{fhir_id}        - Importar desde FHIR"
echo ""
echo -e "${YELLOW}Para probar:${NC}"
echo "  1. Hacer port-forward:"
echo "     kubectl port-forward -n citus service/middleware-citus-service 8000:8000"
echo ""
echo "  2. Ver documentación:"
echo "     http://localhost:8000/docs"
echo ""
echo "  3. Verificar salud:"
echo "     curl http://localhost:8000/health"
echo ""
echo -e "${GREEN}¡Sistema con FHIR operativo!${NC}\n"
