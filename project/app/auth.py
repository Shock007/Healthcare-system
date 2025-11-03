# project/app/auth.py
import os
from datetime import datetime, timedelta
import jwt
from fastapi import HTTPException, Header

SECRET_KEY = os.getenv("SECRET_KEY", "cambia_esto_para_produccion")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))

def generar_jwt(data: dict):
    expiration = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = data.copy()
    to_encode.update({"exp": datetime.utcnow() + expiration})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def validar_jwt(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido")

def obtener_token_desde_header(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Formato de autorización inválido")
    token = authorization.split(" ")[1]
    return validar_jwt(token)
