from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_admin
from app.db.session import get_db
from app.models.enums import STAFF_ROLES
from app.models.user import User
from app.schemas.auth import UserOut
from app.schemas.user import UserPublic

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserPublic])
def list_staff(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    """Lista agentes/admins ativos, usada para preencher o seletor de responsável no app."""
    return list(
        db.scalars(
            select(User).where(User.role.in_(STAFF_ROLES), User.is_active.is_(True)).order_by(User.name)
        ).all()
    )


@router.get("/all", response_model=list[UserOut])
def list_all_users(db: Session = Depends(get_db), admin: User = Depends(require_admin)):
    """Lista completa de usuários — restrita a administradores."""
    return list(db.scalars(select(User).order_by(User.name)).all())
