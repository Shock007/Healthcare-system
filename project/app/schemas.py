import os
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

