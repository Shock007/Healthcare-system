#!/bin/bash
# setup.sh - Script de configuración automática Semana 1
# Historia Clínica Distribuida

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Historia Clínica Distribuida - Setup${NC}"
echo -e "${GREEN}  Semana 1: Infraestructura + Middleware${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Función para imprimir pasos
print_step() {
    echo -e "\n${YELLOW}[PASO $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Variables
NAMESPACE="citus"
PROJECT_DIR="project"

# ==================== PASO 1: Verificar requisitos ====================
print_step 1 "Verificando requisitos previos..."

command -v minikube >/dev/null 2>&1 && print_success "Minikube instalado" || print_error "Minikube NO instalado"
command -v kubectl >/dev/null 2>&1 && print_success "kubectl instalado" || print_error "kubectl NO instalado"
command -v docker >/dev/null 2>&1 && print_success "Docker instalado" || print_error "Docker NO instalado"
command -v python3 >/dev/null 2>&1 && print_success "Python3 instalado" || print_error "Python3 NO instalado"

# ==================== PASO 2: Iniciar Minikube ====================
print_step 2 "Iniciando Minikube..."

if minikube status | grep -q "Running"; then
    print_success "Minikube ya está corriendo"
else
    minikube start --cpus=4 --memory=4096 --driver=docker
    print_success "Minikube iniciado"
fi

# ==================== PASO 3: Crear namespace ====================
print_step 3 "Creando namespace..."

if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    print_success "Namespace '$NAMESPACE' ya existe"
else
    kubectl create namespace $NAMESPACE
    print_success "Namespace '$NAMESPACE' creado"
fi

# ==================== PASO 4: Desplegar Citus ====================
print_step 4 "Desplegando Citus..."

kubectl apply -f $PROJECT_DIR/citus-deployment.yaml

echo "Esperando a que los pods estén listos (esto puede tomar 1-2 minutos)..."
kubectl wait --for=condition=ready pod -l app=citus-coordinator -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=citus-worker -n $NAMESPACE --timeout=300s

print_success "Citus desplegado correctamente"

# ==================== PASO 5: Configurar base de datos ====================
print_step 5 "Configurando base de datos..."

COORDINATOR_POD=$(kubectl get pod -n $NAMESPACE -l app=citus-coordinator -o jsonpath="{.items[0].metadata.name}")

echo "Pod coordinador: $COORDINATOR_POD"

# Crear base de datos y extensiones
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -c "CREATE DATABASE historiaclinica;" 2>/dev/null || echo "BD ya existe"
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica -c "CREATE EXTENSION IF NOT EXISTS citus;"
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

print_success "Extensiones creadas"

# Crear esquema y tabla
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica <<EOF
CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE IF NOT EXISTS public.pacientes (
    id SERIAL,
    documento_id VARCHAR(20) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100),
    fecha_nacimiento DATE,
    telefono VARCHAR(20),
    direccion TEXT,
    correo VARCHAR(100),
    genero VARCHAR(10),
    tipo_sangre VARCHAR(5),
    fecha_registro TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (documento_id, id)
);
EOF

print_success "Tabla pacientes creada"

# Distribuir tabla
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica -c "SELECT create_distributed_table('public.pacientes', 'documento_id');" 2>/dev/null || print_success "Tabla ya distribuida"

# Insertar datos de prueba
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica <<EOF
INSERT INTO public.pacientes (documento_id, nombre, apellido, fecha_nacimiento, telefono, direccion, correo, genero, tipo_sangre)
VALUES
('12345', 'Juan', 'Pérez', '1995-04-12', '3001234567', 'Calle 123 #45-67', 'juanp@example.com', 'M', 'O+'),
('67890', 'María', 'Gómez', '1989-09-30', '3109876543', 'Carrera 45 #12-34', 'mariag@example.com', 'F', 'A+'),
('11111', 'Pedro', 'López', '1992-06-15', '3201112233', 'Avenida 80 #20-10', 'pedro@example.com', 'M', 'B+')
ON CONFLICT DO NOTHING;
EOF

print_success "Datos de prueba insertados"

# ==================== PASO 6: Construir imagen Docker ====================
print_step 6 "Construyendo imagen Docker..."

cd $PROJECT_DIR
docker build -t middleware-citus:1.0 .
cd ..

print_success "Imagen construida: middleware-citus:1.0"

# Cargar en Minikube
minikube image load middleware-citus:1.0
print_success "Imagen cargada en Minikube"

# ==================== PASO 7: Crear secrets ====================
print_step 7 "Creando secrets de Kubernetes..."

kubectl create secret generic app-secrets \
  --from-literal=POSTGRES_HOST=citus-coordinator \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=POSTGRES_DB=historiaclinica \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=password \
  --from-literal=SECRET_KEY=20240902734 \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

print_success "Secrets creados"

# ==================== PASO 8: Desplegar middleware ====================
print_step 8 "Desplegando middleware FastAPI..."

kubectl apply -f $PROJECT_DIR/infra/app-deployment.yaml

echo "Esperando a que el middleware esté listo..."
kubectl wait --for=condition=ready pod -l app=middleware-citus -n $NAMESPACE --timeout=300s

print_success "Middleware desplegado"

# ==================== PASO 9: Verificación ====================
print_step 9 "Verificando instalación..."

echo -e "\n${YELLOW}Estado de los pods:${NC}"
kubectl get pods -n $NAMESPACE

echo -e "\n${YELLOW}Servicios:${NC}"
kubectl get svc -n $NAMESPACE

echo -e "\n${YELLOW}Verificando datos en BD:${NC}"
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica -c "SELECT COUNT(*) as total_pacientes FROM public.pacientes;"

echo -e "\n${YELLOW}Verificando distribución:${NC}"
kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica -c "SELECT * FROM citus_tables;"

# ==================== PASO 10: Instrucciones finales ====================
print_step 10 "Configuración completa!"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ INSTALACIÓN COMPLETADA${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Para acceder a la API:${NC}"
echo "  kubectl port-forward -n $NAMESPACE service/middleware-citus-service 8000:8000"
echo ""
echo -e "${YELLOW}Luego probar:${NC}"
echo "  curl http://localhost:8000/health"
echo ""
echo -e "${YELLOW}Para obtener un token:${NC}"
echo '  curl -X POST http://localhost:8000/token \'
echo '    -H "Content-Type: application/json" \'
echo '    -d '"'"'{"username":"admin","password":"admin"}'"'"
echo ""
echo -e "${YELLOW}Para ver logs del middleware:${NC}"
echo "  kubectl logs -n $NAMESPACE -l app=middleware-citus -f"
echo ""
echo -e "${YELLOW}Para conectarte a la base de datos:${NC}"
echo "  kubectl exec -it -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica"
echo ""
echo -e "${GREEN}¡Todo listo para la Semana 1!${NC}\n"
