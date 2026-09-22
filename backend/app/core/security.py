import hashlib
import hmac
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ACCESS_TOKEN_SCOPE = "access"
PASSWORD_RESET_SCOPE = "password_reset"


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def create_access_token(
    subject: str,
    minutes: int | None = None,
) -> str:
    settings = get_settings()

    ttl_minutes = (
        settings.access_token_minutes
        if minutes is None
        else minutes
    )

    expire = datetime.now(timezone.utc) + timedelta(
        minutes=ttl_minutes,
    )

    return jwt.encode(
        {
            "sub": subject,
            "scope": ACCESS_TOKEN_SCOPE,
            "exp": expire,
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_token(token: str) -> str | None:
    """Aceita somente tokens de acesso."""

    settings = get_settings()

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except JWTError:
        return None

    if payload.get("scope") not in (
        None,
        ACCESS_TOKEN_SCOPE,
    ):
        return None

    subject = payload.get("sub")

    return subject if isinstance(subject, str) else None


def create_scoped_token(
    subject: str,
    scope: str,
    hours: int,
) -> str:
    """Cria um token de propósito único."""

    settings = get_settings()

    expire = datetime.now(timezone.utc) + timedelta(
        hours=hours,
    )

    return jwt.encode(
        {
            "sub": subject,
            "scope": scope,
            "exp": expire,
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_scoped_token(
    token: str,
    expected_scope: str,
) -> str | None:
    settings = get_settings()

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except JWTError:
        return None

    if payload.get("scope") != expected_scope:
        return None

    subject = payload.get("sub")

    return subject if isinstance(subject, str) else None


def _password_hash_version(
    password_hash: str,
) -> str:
    return hashlib.sha256(
        password_hash.encode("utf-8"),
    ).hexdigest()


def create_password_reset_token(
    subject: str,
    password_hash: str,
    minutes: int,
) -> str:
    settings = get_settings()

    expire = datetime.now(timezone.utc) + timedelta(
        minutes=minutes,
    )

    return jwt.encode(
        {
            "sub": subject,
            "scope": PASSWORD_RESET_SCOPE,
            "ver": _password_hash_version(
                password_hash,
            ),
            "exp": expire,
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_password_reset_token(
    token: str,
) -> tuple[str, str] | None:
    settings = get_settings()

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except JWTError:
        return None

    if payload.get("scope") != PASSWORD_RESET_SCOPE:
        return None

    subject = payload.get("sub")
    version = payload.get("ver")

    if not isinstance(subject, str):
        return None

    if not isinstance(version, str):
        return None

    return subject, version


def password_reset_version_matches(
    password_hash: str,
    version: str,
) -> bool:
    expected = _password_hash_version(
        password_hash,
    )

    return hmac.compare_digest(
        expected,
        version,
    )