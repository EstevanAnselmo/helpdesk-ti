import logging
import smtplib
import ssl
from email.message import EmailMessage
from html import escape
from urllib.parse import urlencode

from app.core.config import get_settings

logger = logging.getLogger("helpdesk.email")


def _send(to_email: str, subject: str, html_body: str, text_body: str) -> bool:
    """Envia a mensagem sem desfazer um cadastro já gravado caso o SMTP falhe."""
    settings = get_settings()

    if not settings.smtp_configured:
        if settings.is_production:
            logger.error("SMTP não configurado; e-mail de confirmação não foi enviado.")
        else:
            logger.warning(
                "SMTP não configurado — e-mail para %s não foi enviado de verdade.\n%s",
                to_email,
                text_body,
            )
        return False

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = settings.smtp_from
    message["To"] = to_email
    message.set_content(text_body)
    message.add_alternative(html_body, subtype="html")

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as server:
            server.ehlo()

            if settings.smtp_use_tls:
                server.starttls(context=ssl.create_default_context())
                server.ehlo()

            if settings.smtp_user:
                if not settings.smtp_password:
                    raise RuntimeError("SMTP_USER foi definido sem SMTP_PASSWORD")
                server.login(settings.smtp_user, settings.smtp_password)

            server.send_message(message)
    except (OSError, RuntimeError, ValueError, smtplib.SMTPException):
        logger.exception("Falha ao enviar e-mail de confirmação para %s.", to_email)
        return False

    return True


def send_verification_email(to_email: str, name: str, token: str) -> bool:
    settings = get_settings()
    link = f"{settings.app_base_url.rstrip('/')}/api/auth/verify-email?{urlencode({'token': token})}"

    safe_name = escape(name)
    safe_link = escape(link, quote=True)

    subject = "Confirme sua conta — HelpDesk TI"
    text_body = (
        f"Olá, {name}!\n\n"
        "Confirme seu cadastro no HelpDesk TI clicando no link abaixo "
        f"(válido por {settings.email_verification_token_hours}h):\n\n"
        f"{link}\n\n"
        "Se você não solicitou este cadastro, ignore este e-mail."
    )

    html_body = f"""
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color:#3949ab;">HelpDesk TI</h2>
      <p>Olá, <strong>{safe_name}</strong>!</p>
      <p>Confirme seu cadastro clicando no botão abaixo:</p>
      <p style="text-align:center; margin: 24px 0;">
        <a href="{safe_link}" style="background:#3949ab; color:#fff; padding:12px 24px;
           border-radius:6px; text-decoration:none; display:inline-block;">
           Confirmar minha conta
        </a>
      </p>
      <p style="color:#666; font-size:13px;">
        Este link expira em {settings.email_verification_token_hours} horas.
        Se você não solicitou este cadastro, ignore este e-mail.
      </p>
    </div>
    """

    return _send(to_email, subject, html_body, text_body)