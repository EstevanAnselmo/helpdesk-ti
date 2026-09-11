import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.email import send_verification_email
from app.core.security import (
    create_access_token,
    create_scoped_token,
    decode_scoped_token,
    hash_password,
    verify_password,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    MessageResponse,
    RegisterResponse,
    ResendVerificationRequest,
    TokenResponse,
    UserCreate,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger("helpdesk.auth")

EMAIL_VERIFICATION_SCOPE = "email_verification"


def _issue_verification_email(user: User) -> bool:
    """Gera e tenta enviar o link sem transformar um cadastro salvo em erro 500."""
    settings = get_settings()

    token = create_scoped_token(
        str(user.id),
        EMAIL_VERIFICATION_SCOPE,
        settings.email_verification_token_hours,
    )

    try:
        return send_verification_email(user.email, user.name, token)
    except Exception:
        logger.exception("Falha ao enviar confirmação de e-mail para user_id=%s", user.id)
        return False


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(data: UserCreate, db: Session = Depends(get_db)):
    user = User(
        name=data.name,
        email=data.email,
        password_hash=hash_password(data.password),
        email_verified=False,
    )

    db.add(user)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="E-mail já cadastrado",
        )

    db.refresh(user)

    delivered = _issue_verification_email(user)

    message = (
        "Cadastro realizado. Enviamos um link de confirmação para o seu e-mail."
        if delivered
        else (
            "Cadastro realizado, mas não foi possível enviar o e-mail de confirmação agora. "
            "Tente reenviar o link em alguns minutos."
        )
    )

    return RegisterResponse(message=message, user=user)


@router.get("/verify-email", response_class=HTMLResponse)
def verify_email(token: str, db: Session = Depends(get_db)):
    subject = decode_scoped_token(token, EMAIL_VERIFICATION_SCOPE)
    user = db.get(User, int(subject)) if subject and subject.isdigit() else None

    if not user or not user.is_active:
        return HTMLResponse(
            _verification_page("Link inválido ou expirado.", success=False),
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    if not user.email_verified:
        user.email_verified = True
        db.commit()

    return HTMLResponse(
        _verification_page(
            "E-mail confirmado com sucesso! Você já pode fazer login no app.",
            success=True,
        )
    )


def _verification_page(message: str, success: bool) -> str:
    color = "#2e7d32" if success else "#c62828"
    icon = "&#10003;" if success else "&#10007;"

    return f"""
    <html><head><meta charset="utf-8"><title>HelpDesk TI</title></head>
    <body style="font-family: Arial, sans-serif; display:flex; align-items:center; justify-content:center;
                 height:100vh; margin:0; background:#f4f4f7;">
      <div style="text-align:center; background:#fff; padding:40px; border-radius:12px; box-shadow:0 2px 12px rgba(0,0,0,.08);">
        <div style="font-size:48px; color:{color};">{icon}</div>
        <h2 style="color:#3949ab;">HelpDesk TI</h2>
        <p style="color:#333;">{message}</p>
      </div>
    </body></html>
    """


@router.post("/resend-verification", response_model=MessageResponse)
def resend_verification(data: ResendVerificationRequest, db: Session = Depends(get_db)):
    generic_message = "Se o e-mail existir e ainda não tiver sido confirmado, enviamos um novo link."

    user = db.scalar(select(User).where(User.email == data.email.lower()))

    if user and user.is_active and not user.email_verified:
        _issue_verification_email(user)

    return MessageResponse(message=generic_message)


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == data.email.lower()))

    if not user or not user.is_active or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha inválidos",
        )

    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="E-mail ainda não confirmado. Verifique sua caixa de entrada.",
        )

    settings = get_settings()

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        expires_in_minutes=settings.access_token_minutes,
        user=user,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(user: User = Depends(get_current_user)):
    """Renova um token válido sem exigir novo login."""
    settings = get_settings()

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        expires_in_minutes=settings.access_token_minutes,
        user=user,
    )


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user