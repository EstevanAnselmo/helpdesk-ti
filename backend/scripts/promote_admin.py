"""Promove um usuário existente a admin. Uso: python -m scripts.promote_admin email@exemplo.com

Não existe endpoint HTTP para isso de propósito: promover papéis é uma ação
sensível e não deve ser exposta publicamente pela API.
"""
import sys

from app.db.session import SessionLocal
from app.models.enums import UserRole
from app.models.user import User


def main() -> None:
    if len(sys.argv) != 2:
        print("Uso: python -m scripts.promote_admin email@exemplo.com")
        raise SystemExit(1)

    email = sys.argv[1].strip().lower()
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one_or_none()
        if not user:
            print(f"Usuário '{email}' não encontrado.")
            raise SystemExit(1)
        user.role = UserRole.admin
        db.commit()
        print(f"'{email}' agora é admin.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
