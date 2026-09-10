from pydantic import BaseModel

from app.models.enums import UserRole


class UserPublic(BaseModel):
    id: int
    name: str
    role: UserRole

    model_config = {"from_attributes": True}
