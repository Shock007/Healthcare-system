# project/app/database.py
# project/app/database.py
import os
from psycopg2 import connect, OperationalError
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv(override=False)

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "citus-coordinator")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", 5432))
POSTGRES_DB = os.getenv("POSTGRES_DB", "historiaclinica")
POSTGRES_USER = os.getenv("POSTGRES_USER", "citus")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "citus")

def get_db_connection():
    try:
        conn = connect(
            host=POSTGRES_HOST,
            port=POSTGRES_PORT,
            dbname=POSTGRES_DB,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD,
            cursor_factory=RealDictCursor
        )
        return conn
    except OperationalError as e:
        raise RuntimeError(f"Error conectando a la BD: {e}")

