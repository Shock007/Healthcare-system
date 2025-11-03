# project/app/database.py
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import HTTPException

DB_HOST = os.getenv("DATABASE_HOST", "localhost")  # en k8s: citus-coordinator (o citus-coordinator.citus.svc.cluster.local)
DB_NAME = os.getenv("DATABASE_NAME", "postgres")
DB_USER = os.getenv("DATABASE_USER", "postgres")
DB_PASSWORD = os.getenv("DATABASE_PASSWORD", "password")
DB_PORT = int(os.getenv("DATABASE_PORT", 5432))

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            port=DB_PORT,
            cursor_factory=RealDictCursor
        )
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al conectar con la base de datos: {e}")
