from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.comment import TicketComment
from app.models.enums import STAFF_ROLES, TicketPriority, TicketStatus
from app.models.ticket import Ticket
from app.models.user import User
from app.schemas.ticket import CommentCreate, CommentOut, TicketCreate, TicketListOut, TicketOut, TicketUpdate

router = APIRouter(prefix="/tickets", tags=["tickets"])


def _ticket_or_404(db: Session, ticket_id: int) -> Ticket:
    ticket = db.get(Ticket, ticket_id, options=[selectinload(Ticket.creator), selectinload(Ticket.assignee)])
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chamado não encontrado")
    return ticket


def _ensure_can_view(ticket: Ticket, user: User) -> None:
    is_owner_or_assignee = ticket.creator_id == user.id or ticket.assignee_id == user.id
    if user.role not in STAFF_ROLES and not is_owner_or_assignee:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso negado")


@router.get("", response_model=TicketListOut)
def list_tickets(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    status_filter: TicketStatus | None = Query(default=None, alias="status"),
    priority: TicketPriority | None = None,
    category: str | None = None,
    search: str | None = Query(default=None, description="Busca por título ou descrição"),
    mine: bool = Query(default=False, description="Somente chamados criados por mim ou atribuídos a mim"),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    stmt = select(Ticket).options(selectinload(Ticket.creator), selectinload(Ticket.assignee))

    # Quem não é da equipe de suporte só enxerga os próprios chamados.
    if user.role not in STAFF_ROLES or mine:
        stmt = stmt.where(or_(Ticket.creator_id == user.id, Ticket.assignee_id == user.id))
    if status_filter is not None:
        stmt = stmt.where(Ticket.status == status_filter)
    if priority is not None:
        stmt = stmt.where(Ticket.priority == priority)
    if category:
        stmt = stmt.where(Ticket.category.ilike(f"%{category}%"))
    if search:
        like = f"%{search}%"
        stmt = stmt.where(or_(Ticket.title.ilike(like), Ticket.description.ilike(like)))

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    items = db.scalars(stmt.order_by(Ticket.created_at.desc()).offset(skip).limit(limit)).all()
    return TicketListOut(items=list(items), total=total, skip=skip, limit=limit)


@router.get("/stats/summary")
def stats(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    stmt = select(Ticket.status, func.count(Ticket.id))
    if user.role not in STAFF_ROLES:
        stmt = stmt.where(or_(Ticket.creator_id == user.id, Ticket.assignee_id == user.id))
    rows = db.execute(stmt.group_by(Ticket.status)).all()
    result = {s.value: 0 for s in TicketStatus}
    result.update({(s.value if hasattr(s, "value") else s): count for s, count in rows})
    result["total"] = sum(v for k, v in result.items() if k != "total")
    return result


@router.get("/{ticket_id}", response_model=TicketOut)
def get_ticket(ticket_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    ticket = _ticket_or_404(db, ticket_id)
    _ensure_can_view(ticket, user)
    return ticket


@router.post("", response_model=TicketOut, status_code=status.HTTP_201_CREATED)
def create_ticket(data: TicketCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    ticket = Ticket(
        title=data.title.strip(),
        description=data.description.strip(),
        category=data.category.strip(),
        priority=data.priority,
        creator_id=user.id,
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    return _ticket_or_404(db, ticket.id)


@router.patch("/{ticket_id}", response_model=TicketOut)
def update_ticket(
    ticket_id: int, data: TicketUpdate, db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    ticket = _ticket_or_404(db, ticket_id)
    if user.role not in STAFF_ROLES and ticket.creator_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso negado")

    if data.status is not None:
        ticket.status = data.status
    if data.priority is not None:
        if user.role not in STAFF_ROLES:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Somente a equipe de suporte pode alterar a prioridade")
        ticket.priority = data.priority
    if data.assignee_id is not None:
        if user.role not in STAFF_ROLES:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Somente a equipe de suporte pode atribuir chamados")
        assignee = db.get(User, data.assignee_id)
        if not assignee or assignee.role not in STAFF_ROLES:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Responsável inválido")
        ticket.assignee_id = assignee.id

    db.commit()
    db.refresh(ticket)
    return _ticket_or_404(db, ticket.id)


@router.get("/{ticket_id}/comments", response_model=list[CommentOut])
def list_comments(ticket_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    ticket = _ticket_or_404(db, ticket_id)
    _ensure_can_view(ticket, user)
    return list(
        db.scalars(
            select(TicketComment)
            .options(selectinload(TicketComment.author))
            .where(TicketComment.ticket_id == ticket_id)
            .order_by(TicketComment.created_at)
        ).all()
    )


@router.post("/{ticket_id}/comments", response_model=CommentOut, status_code=status.HTTP_201_CREATED)
def add_comment(
    ticket_id: int, data: CommentCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    ticket = _ticket_or_404(db, ticket_id)
    _ensure_can_view(ticket, user)
    comment = TicketComment(ticket_id=ticket.id, author_id=user.id, content=data.content.strip())
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return db.get(TicketComment, comment.id, options=[selectinload(TicketComment.author)])
