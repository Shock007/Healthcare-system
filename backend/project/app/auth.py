# project/app/auth.py - VERSIÓN CORREGIDA V2
import os
from datetime import datetime, timedelta
from typing import Optional
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from dotenv import load_dotenv

load_dotenv(override=False)

SECRET_KEY = os.getenv("SECRET_KEY", "cambia_esto_en_produccion")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))

# Usar HTTPBearer estándar (sin personalización)
security = HTTPBearer()


def generar_jwt(data: dict) -> str:
    """
    Genera un token JWT con los datos proporcionados.

    Args:
        data: Diccionario con la información a incluir en el token

    Returns:
        str: Token JWT codificado
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return token


def validar_jwt_token(token: str) -> dict:
    """
    Valida un token JWT y retorna el payload.

    Args:
        token: Token JWT a validar

    Returns:
        dict: Payload del token

    Raises:
        HTTPException: Si el token es inválido o ha expirado
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=401,
            detail="Token expirado",
            headers={"WWW-Authenticate": "Bearer"}
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=401,
            detail="Token inválido",
            headers={"WWW-Authenticate": "Bearer"}
        )


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    """
    Dependency para obtener el usuario actual desde el token JWT.

    IMPORTANTE: Esta función maneja automáticamente el caso donde no hay token,
    convirtiendo el 403 de HTTPBearer en un 401 apropiado.

    Args:
        credentials: Credenciales HTTP Bearer extraídas del header

    Returns:
        dict: Payload del token validado

    Raises:
        HTTPException: Si el token es inválido o falta
    """
    if not credentials:
        raise HTTPException(
            status_code=401,
            detail="Falta header Authorization",
            headers={"WWW-Authenticate": "Bearer"}
        )

    token = credentials.credentials
    return validar_jwt_token(token)


def require_auth(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> dict:
    """
    Dependency alternativo que convierte automáticamente 403 en 401.

    Usa Optional para capturar el caso donde HTTPBearer retornaría 403,
    y lo convierte en 401 que es el código HTTP correcto.

    Args:
        credentials: Credenciales HTTP Bearer (opcional)

    Returns:
        dict: Payload del token validado

    Raises:
        HTTPException: 401 si falta token o es inválido
    """
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Falta header Authorization",
            headers={"WWW-Authenticate": "Bearer"}
        )

    return get_current_user(credentials)


