from pydantic import BaseModel, EmailStr, Field, field_validator

from app.core.config import get_settings
from app.models.enums import UserRole


def _min_password_length() -> int:
    return get_settings().password_min_length


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    @field_validator("password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        min_len = _min_password_length()
        if len(value) < min_len:
            raise ValueError(f"A senha deve ter pelo menos {min_len} caracteres")
        if value.isdigit() or value.isalpha():
            raise ValueError("A senha deve combinar letras e números")
        return value


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    role: UserRole
    is_active: bool

    # Sem isto, o FastAPI não consegue serializar um objeto ORM (User) como
    # este schema — era o bug que quebrava /auth/register, /auth/login e
    # /auth/me com erro 500 no protótipo original.
    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    user: UserOut
