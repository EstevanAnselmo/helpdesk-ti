from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ACCESS_TOKEN_SCOPE = "access"


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def create_access_token(subject: str, minutes: int | None = None) -> str:
    settings = get_settings()
    ttl_minutes = settings.access_token_minutes if minutes is None else minutes
    expire = datetime.now(timezone.utc) + timedelta(minutes=ttl_minutes)

    return jwt.encode(
        {"sub": subject, "scope": ACCESS_TOKEN_SCOPE, "exp": expire},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_token(token: str) -> str | None:
    """Aceita somente tokens de acesso; rejeita tokens de confirmação de e-mail."""
    settings = get_settings()

    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None

    # Tokens antigos sem scope continuam válidos até expirarem.
    if payload.get("scope") not in (None, ACCESS_TOKEN_SCOPE):
        return None

    subject = payload.get("sub")
    return subject if isinstance(subject, str) else None


def create_scoped_token(subject: str, scope: str, hours: int) -> str:
    """Cria um token de propósito único, como confirmação de e-mail."""
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(hours=hours)

    return jwt.encode(
        {"sub": subject, "scope": scope, "exp": expire},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_scoped_token(token: str, expected_scope: str) -> str | None:
    """Retorna o id somente se o token tiver o escopo esperado."""
    settings = get_settings()

    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None

    if payload.get("scope") != expected_scope:
        return None

    subject = payload.get("sub")
    return subject if isinstance(subject, str) else None