# project/app/models.py
import os
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel

class Paciente(BaseModel):
    id: int
    documento_id: int
    nombre: str
    apellido: str
    fecha_nacimiento: str
