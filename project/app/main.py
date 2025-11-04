from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
import psycopg2
from psycopg2 import sql
from datetime import datetime, timedelta
import jwt
from fastapi.security import OAuth2PasswordBearer
from app.auth import obtener_token_desde_header
import os

from dotenv import load_dotenv

# Esto carga las variables de entorno desde un archivo .env
#load_dotenv()
load_dotenv(dotenv_path=".env", override=False)
# Otras importaciones

# Configuración de la base de datos
DATABASE_HOST = os.getenv("DATABASE_HOST", "localhost")
DATABASE_NAME = os.getenv("DATABASE_NAME", "postgres")  # Verifica que sea la misma base de datos
DATABASE_USER = os.getenv("DATABASE_USER", "postgres")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD", "password")


# Función para obtener la conexión a la base de datos
def get_db_connection():
    # Imprime la conexión para depuración
    print(f"Conectando a la base de datos: {os.getenv('DATABASE_NAME', 'postgres')} en {os.getenv('DATABASE_HOST', 'localhost')}")

    conn = psycopg2.connect(
        host=os.getenv("DATABASE_HOST", "localhost"),
        database=os.getenv("DATABASE_NAME", "postgres"),
        user=os.getenv("DATABASE_USER", "postgres"),
        password=os.getenv("DATABASE_PASSWORD", "password")
    )

    return conn


# Inicializamos FastAPI
app = FastAPI(title="Middleware HC - Citus")

# Ruta raíz
@app.get("/")
def read_root():
    return {"message": "Bienvenido a la API de pacientes"}

# Pydantic model para validar los datos del paciente
class Paciente(BaseModel):
    document_id: int
    nombre: str
    apellido: str
    fecha_nacimiento: str

# Endpoint para obtener paciente por ID
@app.get("/paciente/{id}")
def obtener_paciente(id: int):
    conn = get_db_connection()
    cursor = conn.cursor()

    # Depuración: Verifica la conexión
    print(f"Consultando paciente con id={id} en la tabla public.pacientes")

    # Inicializamos la variable paciente
    paciente = None

    try:
        cursor.execute('SELECT * FROM public.pacientes WHERE id = %s', (id,))
        paciente = cursor.fetchone()  # Aquí obtenemos el paciente
    except Exception as e:
        print(f"Error al ejecutar la consulta: {e}")
    finally:
        conn.close()

    # Verificar si no se encuentra el paciente
    if paciente is None:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")

    return {
        "id": paciente[0],
        "documento_id": paciente[1],
        "nombre": paciente[2],
        "apellido": paciente[3],
        "fecha_nacimiento": paciente[4]
    }




# Configuración JWT
SECRET_KEY = "secret_key"  # Cambia esto por una clave segura
ALGORITHM = "HS256"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Clase para recibir los datos del usuario
class AuthRequest(BaseModel):
    username: str
    password: str

# Endpoint para generar el JWT usando datos JSON (auth)
@app.post("/token")
def login_for_token(auth: AuthRequest):
    # Validar las credenciales
    if auth.username == "admin" and auth.password == "admin":
        expiration = timedelta(minutes=30)
        to_encode = {"sub": auth.username, "role": "admin"}
        to_encode.update({"exp": datetime.utcnow() + expiration})
        token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return {"access_token": token, "token_type": "bearer"}
    raise HTTPException(status_code=401, detail="Credenciales inválidas")

# Ruta para obtener el paciente usando JWT
@app.get("/paciente/{paciente_id}")
def get_paciente(paciente_id: int, payload: dict = Depends(obtener_token_desde_header)):
    paciente = obtener_paciente_por_id(paciente_id)
    if not paciente:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    return paciente
