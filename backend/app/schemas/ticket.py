from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import TicketPriority, TicketStatus
from app.schemas.user import UserPublic


class TicketCreate(BaseModel):
    title: str = Field(min_length=3, max_length=180)
    description: str = Field(min_length=5)
    category: str = Field(min_length=2, max_length=60)
    priority: TicketPriority = TicketPriority.medium


class TicketUpdate(BaseModel):
    status: TicketStatus | None = None
    priority: TicketPriority | None = None
    assignee_id: int | None = None


class TicketOut(BaseModel):
    id: int
    title: str
    description: str
    category: str
    priority: TicketPriority
    status: TicketStatus
    creator_id: int
    assignee_id: int | None
    created_at: datetime
    updated_at: datetime
    creator: UserPublic | None = None
    assignee: UserPublic | None = None

    model_config = {"from_attributes": True}


class TicketListOut(BaseModel):
    items: list[TicketOut]
    total: int
    skip: int
    limit: int


class CommentCreate(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class CommentOut(BaseModel):
    id: int
    ticket_id: int
    author_id: int
    content: str
    created_at: datetime
    author: UserPublic | None = None

    model_config = {"from_attributes": True}
