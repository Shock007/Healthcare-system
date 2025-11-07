#!/bin/bash
# apply_fhir_integration.sh - Aplica integración FHIR completa
# Ejecutar desde la raíz del proyecto

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Aplicando Integración FHIR${NC}"
echo -e "${GREEN}========================================${NC}\n"

print_step() { echo -e "\n${YELLOW}[PASO $1]${NC} $2"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Verificar que estamos en el directorio correcto
if [ ! -d "project" ]; then
    print_error "Debe ejecutar desde la raíz del repositorio"
fi

NAMESPACE="citus"

# ==================== PASO 1: Backup ====================
print_step 1 "Creando backup de archivos..."

mkdir -p backups
cp project/app/main.py backups/main.py.backup 2>/dev/null || true
cp project/app/models.py backups/models.py.backup 2>/dev/null || true
cp project/app/schemas.py backups/schemas.py.backup 2>/dev/null || true
cp project/requirements.txt backups/requirements.txt.backup 2>/dev/null || true
cp project/.env backups/.env.backup 2>/dev/null || true

print_success "Backup creado en ./backups/"

# ==================== PASO 2: Actualizar requirements.txt ====================
print_step 2 "Actualizando requirements.txt..."

cat > project/requirements.txt << 'EOF'
fastapi==0.120.4
uvicorn==0.18.3
psycopg2-binary==2.9.10
pyjwt==2.8.0
pydantic
python-dotenv==1.0.1
requests==2.31.0
fhirclient==4.1.0
EOF

print_success "requirements.txt actualizado"

# ==================== PASO 3: Actualizar .env ====================
print_step 3 "Actualizando .env..."

# Solo agregar si no existen
if ! grep -q "FHIR_SERVER_URL" project/.env; then
    cat >> project/.env << 'EOF'

# HAPI FHIR Server
FHIR_SERVER_URL=http://hapi.fhir.org/baseR4
FHIR_TIMEOUT=30
EOF
    print_success ".env actualizado con configuración FHIR"
else
    print_success ".env ya tiene configuración FHIR"
fi

# ==================== PASO 4: Crear fhir_client.py ====================
print_step 4 "Creando app/fhir_client.py..."

cat > project/app/fhir_client.py << 'EOFPYTHON'
# project/app/fhir_client.py
"""Cliente FHIR para HAPI FHIR Server"""
import os
import requests
from typing import Optional, Dict, Any, List
from dotenv import load_dotenv
from fastapi import HTTPException

load_dotenv(override=False)

FHIR_SERVER_URL = os.getenv("FHIR_SERVER_URL", "http://hapi.fhir.org/baseR4")
FHIR_TIMEOUT = int(os.getenv("FHIR_TIMEOUT", 30))


class FHIRClient:
    def __init__(self):
        self.base_url = FHIR_SERVER_URL.rstrip('/')
        self.timeout = FHIR_TIMEOUT
        self.headers = {
            'Content-Type': 'application/fhir+json',
            'Accept': 'application/fhir+json'
        }

    def test_connection(self) -> Dict[str, Any]:
        """Prueba conexión con servidor FHIR"""
        try:
            response = requests.get(
                f"{self.base_url}/metadata",
                headers=self.headers,
                timeout=self.timeout
            )
            response.raise_for_status()
            return {
                "status": "connected",
                "server": self.base_url,
                "fhir_version": response.json().get("fhirVersion", "unknown")
            }
        except requests.exceptions.RequestException as e:
            return {
                "status": "error",
                "server": self.base_url,
                "error": str(e)
            }

    def paciente_to_fhir(self, paciente: Dict[str, Any]) -> Dict[str, Any]:
        """Convierte paciente local a FHIR Patient"""
        fhir_patient = {
            "resourceType": "Patient",
            "identifier": [{
                "use": "official",
                "system": "http://hospital.example.org/identifiers/patient",
                "value": paciente.get("documento_id")
            }],
            "active": True,
            "name": [{
                "use": "official",
                "family": paciente.get("apellido", ""),
                "given": [paciente.get("nombre", "")]
            }],
            "telecom": [],
            "gender": self._map_gender(paciente.get("genero")),
            "birthDate": paciente.get("fecha_nacimiento")
        }

        if paciente.get("telefono"):
            fhir_patient["telecom"].append({
                "system": "phone",
                "value": paciente.get("telefono"),
                "use": "mobile"
            })

        if paciente.get("correo"):
            fhir_patient["telecom"].append({
                "system": "email",
                "value": paciente.get("correo"),
                "use": "home"
            })

        if paciente.get("direccion"):
            fhir_patient["address"] = [{
                "use": "home",
                "text": paciente.get("direccion"),
                "type": "physical"
            }]

        return fhir_patient

    def create_patient(self, paciente: Dict[str, Any]) -> Dict[str, Any]:
        """Crea paciente en servidor FHIR"""
        try:
            fhir_patient = self.paciente_to_fhir(paciente)
            response = requests.post(
                f"{self.base_url}/Patient",
                json=fhir_patient,
                headers=self.headers,
                timeout=self.timeout
            )
            response.raise_for_status()
            return {
                "success": True,
                "fhir_id": response.json().get("id"),
                "data": response.json()
            }
        except requests.exceptions.RequestException as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error al crear paciente en FHIR: {str(e)}"
            )

    def _map_gender(self, genero: Optional[str]) -> str:
        """Mapea género local a FHIR"""
        gender_map = {
            "M": "male",
            "F": "female",
            "O": "other",
            None: "unknown"
        }
        return gender_map.get(genero, "unknown")


# Instancia global
fhir_client = FHIRClient()


def get_fhir_client() -> FHIRClient:
    return fhir_client
EOFPYTHON

print_success "fhir_client.py creado"

# ==================== PASO 5: Actualizar models.py ====================
print_step 5 "Actualizando app/models.py..."

cat > project/app/models.py << 'EOFPYTHON'
# project/app/models.py
from pydantic import BaseModel
from typing import Optional

class Paciente(BaseModel):
    id: int
    documento_id: str
    nombre: str
    apellido: str
    fecha_nacimiento: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    correo: Optional[str] = None
    genero: Optional[str] = None
    tipo_sangre: Optional[str] = None
    fhir_id: Optional[str] = None
EOFPYTHON

print_success "models.py actualizado"

# ==================== PASO 6: Actualizar schemas.py ====================
print_step 6 "Actualizando app/schemas.py..."

cat > project/app/schemas.py << 'EOFPYTHON'
# project/app/schemas.py
from pydantic import BaseModel
from typing import Optional

class AuthRequest(BaseModel):
    username: str
    password: str

class PacienteResponse(BaseModel):
    id: int
    documento_id: str
    nombre: str
    apellido: str
    fecha_nacimiento: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    correo: Optional[str] = None
    genero: Optional[str] = None
    tipo_sangre: Optional[str] = None
    fhir_id: Optional[str] = None

class PacienteCreate(BaseModel):
    documento_id: str
    nombre: str
    apellido: str
    fecha_nacimiento: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    correo: Optional[str] = None
    genero: Optional[str] = None
    tipo_sangre: Optional[str] = None

class FHIRSyncResponse(BaseModel):
    success: bool
    message: str
    fhir_id: Optional[str] = None
    local_id: Optional[int] = None
EOFPYTHON

print_success "schemas.py actualizado"

# ==================== PASO 7: Actualizar main.py ====================
print_step 7 "Actualizando app/main.py con endpoints FHIR..."

cat > project/app/main.py << 'EOFPYTHON'
# project/app/main.py
from fastapi import FastAPI, HTTPException, Depends
from app.database import get_db_connection
from app.models import Paciente
from app.schemas import (
    AuthRequest,
    PacienteResponse,
    PacienteCreate,
    FHIRSyncResponse
)
from app.auth import generar_jwt, validar_jwt
from app.fhir_client import get_fhir_client, FHIRClient
from psycopg2.extras import RealDictCursor
from typing import List

app = FastAPI(
    title="Middleware HC - Citus + FHIR",
    description="API para gestión de historias clínicas distribuidas con integración FHIR",
    version="2.0.0"
)

# ==================== ENDPOINTS PÚBLICOS ====================

@app.get("/", tags=["Sistema"])
def read_root():
    """Endpoint raíz"""
    return {
        "message": "Bienvenido a la API de Historia Clínica Distribuida con FHIR",
        "version": "2.0.0",
        "status": "operational",
        "features": ["Citus DB", "JWT Auth", "FHIR Integration"]
    }

@app.get("/health", tags=["Sistema"])
def health_check():
    """Health check con estado FHIR"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"

    # Verificar FHIR
    fhir = get_fhir_client()
    fhir_status = fhir.test_connection()

    return {
        "status": "healthy" if db_status == "connected" else "degraded",
        "database": db_status,
        "fhir_server": fhir_status
    }

@app.post("/token", tags=["Autenticación"])
def login_for_token(auth: AuthRequest):
    """Genera token JWT"""
    if auth.username == "admin" and auth.password == "admin":
        token = generar_jwt({
            "sub": auth.username,
            "role": "admin"
        })
        return {
            "access_token": token,
            "token_type": "bearer"
        }

    raise HTTPException(
        status_code=401,
        detail="Credenciales inválidas"
    )

# ==================== ENDPOINTS PROTEGIDOS ====================

@app.get("/paciente/{paciente_id}",
         response_model=PacienteResponse,
         tags=["Pacientes"])
def obtener_paciente(
    paciente_id: int,
    payload: dict = Depends(validar_jwt)
):
    """Obtiene paciente por ID"""
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            SELECT id, documento_id, nombre, apellido,
                   fecha_nacimiento, telefono, direccion, correo,
                   genero, tipo_sangre, fhir_id
            FROM public.pacientes
            WHERE id = %s
        """, (paciente_id,))

        row = cur.fetchone()
        cur.close()

        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Paciente con ID {paciente_id} no encontrado"
            )

        return PacienteResponse(**row)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al consultar la base de datos: {str(e)}"
        )
    finally:
        if conn:
            conn.close()

@app.get("/pacientes",
         response_model=List[PacienteResponse],
         tags=["Pacientes"])
def listar_pacientes(
    payload: dict = Depends(validar_jwt),
    limit: int = 10
):
    """Lista pacientes"""
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            SELECT id, documento_id, nombre, apellido,
                   fecha_nacimiento, telefono, direccion, correo,
                   genero, tipo_sangre, fhir_id
            FROM public.pacientes
            ORDER BY id
            LIMIT %s
        """, (limit,))

        rows = cur.fetchall()
        cur.close()

        return [PacienteResponse(**row) for row in rows]

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al consultar la base de datos: {str(e)}"
        )
    finally:
        if conn:
            conn.close()

@app.post("/pacientes",
          response_model=PacienteResponse,
          tags=["Pacientes"],
          status_code=201)
def crear_paciente(
    paciente: PacienteCreate,
    payload: dict = Depends(validar_jwt)
):
    """Crea nuevo paciente"""
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            INSERT INTO public.pacientes
            (documento_id, nombre, apellido, fecha_nacimiento,
             telefono, direccion, correo, genero, tipo_sangre)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, documento_id, nombre, apellido,
                      fecha_nacimiento, telefono, direccion, correo,
                      genero, tipo_sangre, fhir_id
        """, (
            paciente.documento_id,
            paciente.nombre,
            paciente.apellido,
            paciente.fecha_nacimiento,
            paciente.telefono,
            paciente.direccion,
            paciente.correo,
            paciente.genero,
            paciente.tipo_sangre
        ))

        row = cur.fetchone()
        conn.commit()
        cur.close()

        return PacienteResponse(**row)

    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error al crear paciente: {str(e)}"
        )
    finally:
        if conn:
            conn.close()

# ==================== ENDPOINTS FHIR ====================

@app.post("/pacientes/{paciente_id}/sync-to-fhir",
          response_model=FHIRSyncResponse,
          tags=["FHIR"])
def sincronizar_paciente_a_fhir(
    paciente_id: int,
    payload: dict = Depends(validar_jwt)
):
    """Sincroniza paciente a FHIR"""
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            SELECT id, documento_id, nombre, apellido,
                   fecha_nacimiento, telefono, direccion, correo,
                   genero, tipo_sangre, fhir_id
            FROM public.pacientes
            WHERE id = %s
        """, (paciente_id,))

        row = cur.fetchone()

        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Paciente {paciente_id} no encontrado"
            )

        paciente_data = dict(row)
        fhir = get_fhir_client()

        result = fhir.create_patient(paciente_data)
        fhir_id = result["fhir_id"]

        # Actualizar FHIR ID
        cur.execute("""
            UPDATE public.pacientes
            SET fhir_id = %s
            WHERE id = %s
        """, (fhir_id, paciente_id))
        conn.commit()
        cur.close()

        return FHIRSyncResponse(
            success=True,
            message="Paciente sincronizado a FHIR",
            fhir_id=fhir_id,
            local_id=paciente_id
        )

    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error al sincronizar con FHIR: {str(e)}"
        )
    finally:
        if conn:
            conn.close()
EOFPYTHON

print_success "main.py actualizado con endpoints FHIR"

# ==================== PASO 8: Agregar columna fhir_id ====================
print_step 8 "Agregando columna fhir_id a la base de datos..."

COORDINATOR_POD=$(kubectl get pod -n $NAMESPACE -l app=citus-coordinator -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [ -z "$COORDINATOR_POD" ]; then
    print_error "No se encontró el pod coordinador. ¿Está corriendo Minikube?"
fi

kubectl exec -n $NAMESPACE $COORDINATOR_POD -- psql -U postgres -d historiaclinica <<'EOFSQL'
ALTER TABLE public.pacientes
ADD COLUMN IF NOT EXISTS fhir_id VARCHAR(100) UNIQUE;

CREATE INDEX IF NOT EXISTS idx_pacientes_fhir_id
ON public.pacientes(fhir_id);
EOFSQL

print_success "Columna fhir_id agregada"

# ==================== PASO 9: Reconstruir imagen Docker ====================
print_step 9 "Reconstruyendo imagen Docker..."

cd project
docker build -t middleware-citus:1.0 . 2>&1 | tail -5
cd ..

print_success "Imagen Docker construida"

minikube image load middleware-citus:1.0
print_success "Imagen cargada en Minikube"

# ==================== PASO 10: Reiniciar deployment ====================
print_step 10 "Reiniciando deployment..."

kubectl rollout restart deployment/middleware-citus -n $NAMESPACE
sleep 5
kubectl wait --for=condition=ready pod -l app=middleware-citus -n $NAMESPACE --timeout=120s

print_success "Deployment reiniciado"

# ==================== VERIFICACIÓN ====================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ INTEGRACIÓN FHIR APLICADA${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Próximos pasos:${NC}"
echo "1. Hacer port-forward:"
echo "   kubectl port-forward -n citus service/middleware-citus-service 8000:8000 &"
echo ""
echo "2. Verificar health check:"
echo "   curl http://localhost:8000/health"
echo ""
echo "3. Ver documentación:"
echo "   http://localhost:8000/docs"
echo ""
echo "4. Ejecutar tests:"
echo "   ./project/test_fhir.sh"
echo ""
echo -e "${BLUE}Nota:${NC} Los archivos originales están en ./backups/"
echo ""
echo -e "${GREEN}¡Listo!${NC}\n"
