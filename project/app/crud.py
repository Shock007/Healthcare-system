# project/app/crud.py
import os
from fastapi import FastAPI, HTTPException, Depends
from app.database import get_db_connection
from app.models import Paciente

# project/app/crud.py
def obtener_paciente_por_id(paciente_id: int):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT id, documento_id, nombre, apellido, fecha_nacimiento FROM pacientes WHERE id = %s', (paciente_id,))
        row = cursor.fetchone()
        cursor.close()
        conn.close()

        if row:
            return Paciente(
                id=row['id'],
                documento_id=row['documento_id'],
                nombre=row['nombre'],
                apellido=row['apellido'],
                fecha_nacimiento=str(row['fecha_nacimiento'])
            )
        return None
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al obtener paciente: {e}")

