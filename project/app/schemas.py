import os
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel

class PacienteResponse(BaseModel):
    id: int
    document_id: int
    nombre: str
    apellido: str
    fecha_nacimiento: str
