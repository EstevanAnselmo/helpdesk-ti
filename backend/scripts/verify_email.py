"""Confirma manualmente o e-mail de um usuário.

Uso:
    python -m scripts.verify_email email@exemplo.com

Útil em desenvolvimento quando SMTP_HOST ainda não está configurado.
Em produção, a confirmação deve ocorrer pelo link enviado por e-mail.
"""

import sys

from app.db.session import SessionLocal
from app.models.user import User


def main() -> None:
    if len(sys.argv) != 2:
        print("Uso: python -m scripts.verify_email email@exemplo.com")
        raise SystemExit(1)

    email = sys.argv[1].strip().lower()
    db = SessionLocal()

    try:
        user = db.query(User).filter(User.email == email).one_or_none()

        if user is None:
            print(f"Usuário '{email}' não encontrado.")
            raise SystemExit(1)

        if user.email_verified:
            print(f"'{email}' já estava confirmado.")
            return

        user.email_verified = True
        db.commit()
        print(f"'{email}' confirmado manualmente. Já pode fazer login.")

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


if __name__ == "__main__":
    main()