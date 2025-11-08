# project/app/auth.py
import os
from datetime import datetime, timedelta
from typing import Optional
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from dotenv import load_dotenv

load_dotenv(override=False)

SECRET_KEY = os.getenv("SECRET_KEY", "cambia_esto_en_produccion")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))


class HTTPBearerCustom(HTTPBearer):
    """
    HTTPBearer personalizado que retorna 401 en lugar de 403
    cuando no se proporciona el header de autorización.
    """
    async def __call__(self, request) -> Optional[HTTPAuthorizationCredentials]:
        try:
            return await super().__call__(request)
        except HTTPException as e:
            # Cambiar código 403 a 401
            if e.status_code == 403:
                raise HTTPException(
                    status_code=401,
                    detail="Falta header Authorization o token inválido",
                    headers={"WWW-Authenticate": "Bearer"}
                )
            raise e


# Instancia del manejador personalizado
security = HTTPBearerCustom()


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
    credentials: HTTPAuthorizationCredentials = Security(security)
) -> dict:
    """
    Dependency para obtener el usuario actual desde el token JWT.

    Args:
        credentials: Credenciales HTTP Bearer extraídas del header

    Returns:
        dict: Payload del token validado

    Raises:
        HTTPException: Si el token es inválido
    """
    if not credentials:
        raise HTTPException(
            status_code=401,
            detail="Falta header Authorization",
            headers={"WWW-Authenticate": "Bearer"}
        )

    token = credentials.credentials
    return validar_jwt_token(token)
