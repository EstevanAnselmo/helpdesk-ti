"""
Rotas de autenticação do HelpDesk TI.

Aqui ficam: cadastro, confirmação de e-mail, login, refresh de token,
recuperação/redefinição de senha e o endpoint "/me" (dados do usuário logado).

Ideia geral do fluxo:
1) Usuário se cadastra -> recebe e-mail com link de confirmação.
2) Usuário clica no link -> e-mail é marcado como confirmado.
3) Usuário faz login -> recebe um token de acesso (JWT).
4) Se esquecer a senha -> pede um link de recuperação -> abre uma página
   HTML simples -> define uma nova senha.
"""

import json
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.email import send_password_reset_email, send_verification_email
from app.core.security import (
    create_access_token,
    create_password_reset_token,
    create_scoped_token,
    decode_password_reset_token,
    decode_scoped_token,
    hash_password,
    password_reset_version_matches,
    verify_password,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    MessageResponse,
    RegisterResponse,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserCreate,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger("helpdesk.auth")

# "Escopo" usado dentro do token de confirmação de e-mail.
# Isso evita que um token de confirmação seja reaproveitado para outra coisa.
EMAIL_VERIFICATION_SCOPE = "email_verification"

# Mensagens genéricas: não dizemos se o e-mail existe ou não no sistema,
# por segurança (evita que alguém descubra quais e-mails estão cadastrados).
GENERIC_RESEND_MESSAGE = (
    "Se o e-mail existir e ainda não tiver sido confirmado, "
    "enviamos um novo link."
)
GENERIC_FORGOT_PASSWORD_MESSAGE = (
    "Se o e-mail estiver cadastrado, enviaremos um link para redefinir sua senha."
)
INVALID_RESET_LINK_MESSAGE = "Link de redefinição inválido ou expirado"


# ---------------------------------------------------------------------------
# Funções auxiliares (não são rotas, só ajudam as rotas abaixo)
# ---------------------------------------------------------------------------

def _issue_verification_email(user: User) -> bool:
    """
    Cria o token de confirmação e tenta enviar o e-mail para o usuário.

    Retorna True se o e-mail foi enviado, False se algo deu errado.
    Importante: se o envio falhar, o cadastro do usuário NÃO é desfeito.
    """
    settings = get_settings()
    token = create_scoped_token(
        str(user.id),
        EMAIL_VERIFICATION_SCOPE,
        settings.email_verification_token_hours,
    )

    try:
        return send_verification_email(user.email, user.name, token)
    except Exception:
        logger.exception(
            "Falha ao enviar confirmação de e-mail para user_id=%s", user.id
        )
        return False


def _issue_password_reset_email(user: User) -> bool:
    """
    Cria o token de recuperação de senha e tenta enviar o e-mail.

    Retorna True se o e-mail foi enviado, False se algo deu errado.
    """
    settings = get_settings()
    token = create_password_reset_token(
        str(user.id),
        user.password_hash,
        settings.password_reset_token_minutes,
    )

    try:
        return send_password_reset_email(user.email, user.name, token)
    except Exception:
        logger.exception(
            "Falha ao enviar recuperação de senha para user_id=%s", user.id
        )
        return False


def _get_user_by_email(db: Session, email: str) -> User | None:
    """Busca um usuário pelo e-mail (sempre em minúsculas)."""
    return db.scalar(select(User).where(User.email == email.lower()))


# ---------------------------------------------------------------------------
# Cadastro e confirmação de e-mail
# ---------------------------------------------------------------------------

@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(data: UserCreate, db: Session = Depends(get_db)):
    """Cria um novo usuário e dispara o e-mail de confirmação."""
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
        # Já existe um usuário com esse e-mail (restrição UNIQUE no banco).
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="E-mail já cadastrado",
        )

    db.refresh(user)

    email_delivered = _issue_verification_email(user)

    if email_delivered:
        message = "Cadastro realizado. Enviamos um link de confirmação para o seu e-mail."
    else:
        message = (
            "Cadastro realizado, mas não foi possível enviar o e-mail de "
            "confirmação agora. Tente reenviar o link em alguns minutos."
        )

    return RegisterResponse(message=message, user=user)


@router.get("/verify-email", response_class=HTMLResponse)
def verify_email(token: str, db: Session = Depends(get_db)):
    """
    Endpoint acessado pelo link enviado por e-mail.

    Decodifica o token, confirma o e-mail do usuário e mostra uma
    página HTML simples de sucesso ou erro.
    """
    user_id = decode_scoped_token(token, EMAIL_VERIFICATION_SCOPE)
    user = db.get(User, int(user_id)) if user_id and user_id.isdigit() else None

    if not user or not user.is_active:
        html = _render_status_page(
            title="HelpDesk TI",
            message="Link inválido ou expirado.",
            success=False,
        )
        return HTMLResponse(html, status_code=status.HTTP_400_BAD_REQUEST)

    if not user.email_verified:
        user.email_verified = True
        db.commit()

    html = _render_status_page(
        title="HelpDesk TI",
        message="E-mail confirmado com sucesso! Você já pode fazer login no app.",
        success=True,
    )
    return HTMLResponse(html)


@router.post("/resend-verification", response_model=MessageResponse)
def resend_verification(data: ResendVerificationRequest, db: Session = Depends(get_db)):
    """Reenvia o e-mail de confirmação, se o usuário existir e ainda não tiver confirmado."""
    user = _get_user_by_email(db, data.email)

    if user and user.is_active and not user.email_verified:
        _issue_verification_email(user)

    # Resposta genérica de propósito: não revela se o e-mail existe.
    return MessageResponse(message=GENERIC_RESEND_MESSAGE)


# ---------------------------------------------------------------------------
# Recuperação e redefinição de senha
# ---------------------------------------------------------------------------

@router.post("/forgot-password", response_model=MessageResponse)
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """
    Solicita recuperação de senha.

    A resposta é propositalmente genérica para não revelar se um
    e-mail existe no sistema.
    """
    user = _get_user_by_email(db, data.email)

    if user and user.is_active:
        _issue_password_reset_email(user)

    return MessageResponse(message=GENERIC_FORGOT_PASSWORD_MESSAGE)


def _decode_and_validate_reset_token(db: Session, token: str) -> User | None:
    """
    Decodifica o token de redefinição de senha e devolve o usuário
    correspondente, apenas se o token ainda for válido.

    O token guarda uma "versão" derivada do hash da senha atual: se a
    senha já tiver sido trocada, essa versão não bate mais e o token
    antigo deixa de funcionar automaticamente.
    """
    decoded = decode_password_reset_token(token)
    if decoded is None:
        return None

    subject, version = decoded
    if not subject.isdigit():
        return None

    user = db.get(User, int(subject))
    if not user or not user.is_active:
        return None

    if not password_reset_version_matches(user.password_hash, version):
        return None

    return user


@router.get("/reset-password", response_class=HTMLResponse)
def reset_password_page(token: str, db: Session = Depends(get_db)):
    """Mostra a página de redefinição ou informa que o link é inválido/expirou."""
    user = _decode_and_validate_reset_token(db, token)
    is_token_valid = user is not None

    html = _render_reset_password_page(
        token=token,
        is_token_valid=is_token_valid,
    )

    return HTMLResponse(
        content=html,
        status_code=(
            status.HTTP_200_OK
            if is_token_valid
            else status.HTTP_400_BAD_REQUEST
        ),
        headers={
            "Cache-Control": "no-store",
            "Pragma": "no-cache",
            "Referrer-Policy": "no-referrer",
        },
    )


@router.post("/reset-password", response_model=MessageResponse)
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    """Valida o token de recuperação e salva a nova senha do usuário."""
    user = _decode_and_validate_reset_token(db, data.token)

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=INVALID_RESET_LINK_MESSAGE,
        )

    if verify_password(data.new_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A nova senha deve ser diferente da senha atual",
        )

    user.password_hash = hash_password(data.new_password)

    # O link só chega até aqui porque foi recebido no e-mail cadastrado,
    # então aproveitamos para considerar o e-mail como validado também.
    user.email_verified = True

    db.commit()

    return MessageResponse(message="Senha redefinida com sucesso. Você já pode fazer login.")


# ---------------------------------------------------------------------------
# Login / sessão
# ---------------------------------------------------------------------------

@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    """Autentica o usuário por e-mail e senha e devolve um token de acesso."""
    user = _get_user_by_email(db, data.email)

    invalid_credentials = (
        not user
        or not user.is_active
        or not verify_password(data.password, user.password_hash)
    )
    if invalid_credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha inválidos",
        )

    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="E-mail ainda não confirmado. Verifique sua caixa de entrada.",
        )

    return _build_token_response(user)


@router.post("/refresh", response_model=TokenResponse)
def refresh(user: User = Depends(get_current_user)):
    """Gera um novo token de acesso para um usuário já autenticado (sem pedir login de novo)."""
    return _build_token_response(user)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    """Devolve os dados do usuário atualmente logado."""
    return user


def _build_token_response(user: User) -> TokenResponse:
    """Monta a resposta padrão de token (usada no login e no refresh)."""
    settings = get_settings()
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        expires_in_minutes=settings.access_token_minutes,
        user=user,
    )


# ---------------------------------------------------------------------------
# Páginas HTML simples (confirmação de e-mail e redefinição de senha)
#
# Ficam no final do arquivo de propósito: são só "template" de tela,
# não fazem parte da lógica de negócio das rotas acima.
# ---------------------------------------------------------------------------

def _render_status_page(title: str, message: str, success: bool) -> str:
    """Página de aviso simples (usada em /verify-email)."""
    color = "#2e7d32" if success else "#c62828"
    icon = "&#10003;" if success else "&#10007;"

    return f"""
    <html>
    <head>
        <meta charset="utf-8">
        <title>{title}</title>
    </head>
    <body style="font-family: Arial, sans-serif; display: flex; align-items: center;
                 justify-content: center; height: 100vh; margin: 0; background: #f4f4f7;">
        <div style="text-align: center; background: #ffffff; padding: 40px;
                    border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,.08);">
            <div style="font-size: 48px; color: {color};">{icon}</div>
            <h2 style="color:#3949ab;">{title}</h2>
            <p style="color:#333;">{message}</p>
        </div>
    </body>
    </html>
    """


def _render_reset_password_page(token: str, is_token_valid: bool) -> str:
    """Página onde o usuário define a nova senha (ou a tela de link inválido)."""
    if not is_token_valid:
        return """
        <!DOCTYPE html>
        <html lang="pt-BR">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="referrer" content="no-referrer">
            <title>HelpDesk TI — Recuperar senha</title>
        </head>
        <body style="font-family: Arial, sans-serif; background: #f4f4f7; min-height: 100vh;
                     margin: 0; display: flex; align-items: center; justify-content: center;
                     padding: 24px; box-sizing: border-box;">
            <div style="width: 100%; max-width: 420px; background: #ffffff; padding: 32px;
                        border-radius: 12px; text-align: center;
                        box-shadow: 0 2px 12px rgba(0,0,0,.08);">
                <div style="font-size: 48px; color: #c62828;">&#10007;</div>
                <h2 style="color:#3949ab;">HelpDesk TI</h2>
                <h3>Link inválido ou expirado</h3>
                <p style="color:#666;">
                    Solicite um novo link de recuperação na tela de login do HelpDesk.
                </p>
            </div>
        </body>
        </html>
        """

    # O token vai para dentro do JavaScript da página, por isso usamos
    # json.dumps: ele garante que aspas e caracteres especiais fiquem
    # escapados corretamente dentro do <script>.
    token_as_js_literal = json.dumps(token)

    return f"""
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="referrer" content="no-referrer">
        <title>HelpDesk TI — Redefinir senha</title>
    </head>
    <body style="font-family: Arial, sans-serif; background: #f4f4f7; min-height: 100vh;
                 margin: 0; display: flex; align-items: center; justify-content: center;
                 padding: 24px; box-sizing: border-box;">
        <div style="width: 100%; max-width: 420px; background: #ffffff; padding: 32px;
                    border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,.08);">
            <h2 style="text-align: center; color: #3949ab; margin-bottom: 8px;">HelpDesk TI</h2>
            <h3 style="text-align: center; margin-top: 0;">Redefinir senha</h3>
            <p style="color: #666; text-align: center;">
                Crie uma nova senha com pelo menos 8 caracteres, combinando letras e números.
            </p>

            <label for="password" style="display:block; margin:20px 0 6px; font-weight:600;">
                Nova senha
            </label>
            <input id="password" type="password" autocomplete="new-password"
                   minlength="8" maxlength="128" required
                   placeholder="Nova senha"
                   style="width:100%; box-sizing:border-box; padding:12px;
                          border:1px solid #c7c7c7; border-radius:6px; outline:none;">

            <label for="confirmPassword" style="display:block; margin:14px 0 6px; font-weight:600;">
                Confirmar nova senha
            </label>
            <input id="confirmPassword" type="password" autocomplete="new-password"
                   minlength="8" maxlength="128" required
                   placeholder="Confirme a nova senha"
                   style="width:100%; box-sizing:border-box; padding:12px;
                          border:1px solid #c7c7c7; border-radius:6px; outline:none;">

            <button id="submit" type="button"
                    style="width:100%; padding:12px; margin-top:20px; background:#3949ab;
                           color:#ffffff; border:none; border-radius:6px; cursor:pointer;
                           font-size:15px; font-weight:600;">
                Redefinir senha
            </button>

            <p id="message" aria-live="polite" style="text-align:center; margin-top:16px; min-height:20px;"></p>
        </div>

        <script>
            // Token recebido na URL, injetado aqui pelo backend.
            const token = {token_as_js_literal};

            const submitButton = document.getElementById("submit");
            const passwordInput = document.getElementById("password");
            const confirmationInput = document.getElementById("confirmPassword");
            const message = document.getElementById("message");

            function showError(text) {{
                message.textContent = text;
                message.style.color = "#c62828";
            }}

            function showSuccess(text) {{
                message.textContent = text;
                message.style.color = "#2e7d32";
            }}

            function resetSubmitButton() {{
                submitButton.disabled = false;
                submitButton.textContent = "Redefinir senha";
            }}

            async function submitReset() {{
                const password = passwordInput.value;
                const confirmation = confirmationInput.value;
                message.textContent = "";

                // Validação de UX no navegador. O backend continua sendo a fonte da verdade.
                if (password !== confirmation) {{
                    showError("As senhas não coincidem.");
                    return;
                }}
                if (password.length < 8) {{
                    showError("A senha deve ter pelo menos 8 caracteres.");
                    return;
                }}
                const hasLetter = /[A-Za-z]/.test(password);
                const hasNumber = /[0-9]/.test(password);
                if (!hasLetter || !hasNumber) {{
                    showError("A senha deve combinar letras e números.");
                    return;
                }}

                submitButton.disabled = true;
                submitButton.textContent = "Redefinindo...";

                try {{
                    const response = await fetch("/api/auth/reset-password", {{
                        method: "POST",
                        headers: {{ "Content-Type": "application/json" }},
                        body: JSON.stringify({{ token: token, new_password: password }})
                    }});

                    const data = await response.json();

                    if (!response.ok) {{
                        let detail = data.detail;
                        if (Array.isArray(detail)) {{
                            detail = "A senha não atende aos requisitos.";
                        }}
                        showError(detail || "Não foi possível redefinir a senha.");
                        resetSubmitButton();
                        return;
                    }}

                    showSuccess(
                        "Senha redefinida com sucesso. Você já pode voltar ao HelpDesk e fazer login."
                    );
                    passwordInput.disabled = true;
                    confirmationInput.disabled = true;
                    submitButton.textContent = "Senha redefinida";
                }} catch (error) {{
                    showError("Não foi possível conectar ao HelpDesk. Tente novamente.");
                    resetSubmitButton();
                }}
            }}

            submitButton.addEventListener("click", submitReset);
            confirmationInput.addEventListener("keydown", (event) => {{
                if (event.key === "Enter") {{
                    submitReset();
                }}
            }});
        </script>
    </body>
    </html>
    """