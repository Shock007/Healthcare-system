# project/app/auth.py
# project/app/auth.py
import os
from datetime import datetime, timedelta
from fastapi import HTTPException, Header, Depends
import jwt
from dotenv import load_dotenv

load_dotenv(override=False)

SECRET_KEY = os.getenv("SECRET_KEY", os.getenv("SECRET_KEY", "cambia_esto_en_produccion"))
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))

def generar_jwt(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    # jwt.encode returns str in pyjwt 2.x
    return token

def validar_jwt(token: str = Header(None, alias="Authorization")):
    if not token:
        raise HTTPException(status_code=401, detail="Falta header Authorization")
    # esperar formato "Bearer <token>"
    if token.startswith("Bearer "):
        token = token.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido")
