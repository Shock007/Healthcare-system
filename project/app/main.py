# project/app/main.py
from fastapi import FastAPI, HTTPException, Depends
from app.database import get_db_connection
from app.models import Paciente
from app.schemas import AuthRequest, PacienteResponse
from app.auth import generar_jwt, validar_jwt
from psycopg2.extras import RealDictCursor

app = FastAPI(
    title="Middleware HC - Citus",
    description="API para gestión de historias clínicas distribuidas",
    version="1.0.0"
)

# ==================== ENDPOINTS PÚBLICOS ====================

@app.get("/", tags=["Sistema"])
def read_root():
    """Endpoint raíz para verificar que la API está funcionando"""
    return {
        "message": "Bienvenido a la API de Historia Clínica Distribuida",
        "version": "1.0.0",
        "status": "operational"
    }

@app.get("/health", tags=["Sistema"])
def health_check():
    """Verifica el estado de la API y la conexión a la base de datos"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return {
            "status": "healthy",
            "database": "connected"
        }
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Database connection failed: {str(e)}"
        )

@app.post("/token", tags=["Autenticación"])
def login_for_token(auth: AuthRequest):
    """
    Genera un token JWT para autenticación.

    Credenciales de prueba:
    - username: admin
    - password: admin
    """
    # TODO: Validar contra la base de datos en Semana 2
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
    """
    Obtiene los datos de un paciente por ID.
    Requiere autenticación JWT.
    """
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            SELECT id, documento_id, nombre, apellido,
                   fecha_nacimiento, telefono, direccion, correo
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

        return PacienteResponse(
            id=row['id'],
            documento_id=row['documento_id'],
            nombre=row['nombre'],
            apellido=row['apellido'],
            fecha_nacimiento=str(row['fecha_nacimiento']) if row['fecha_nacimiento'] else None,
            telefono=row.get('telefono'),
            direccion=row.get('direccion'),
            correo=row.get('correo')
        )

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
         response_model=list[PacienteResponse],
         tags=["Pacientes"])
def listar_pacientes(
    payload: dict = Depends(validar_jwt),
    limit: int = 10
):
    """
    Lista todos los pacientes (con límite).
    Requiere autenticación JWT.
    """
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("""
            SELECT id, documento_id, nombre, apellido,
                   fecha_nacimiento, telefono, direccion, correo
            FROM public.pacientes
            ORDER BY id
            LIMIT %s
        """, (limit,))

        rows = cur.fetchall()
        cur.close()

        return [
            PacienteResponse(
                id=row['id'],
                documento_id=row['documento_id'],
                nombre=row['nombre'],
                apellido=row['apellido'],
                fecha_nacimiento=str(row['fecha_nacimiento']) if row['fecha_nacimiento'] else None,
                telefono=row.get('telefono'),
                direccion=row.get('direccion'),
                correo=row.get('correo')
            )
            for row in rows
        ]

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al consultar la base de datos: {str(e)}"
        )
    finally:
        if conn:
            conn.close()
