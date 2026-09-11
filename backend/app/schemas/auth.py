from typing import Any

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

    @field_validator("name", mode="before")
    @classmethod
    def normalize_name(cls, value: Any) -> Any:
        return value.strip() if isinstance(value, str) else value

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.lower()

    @field_validator("password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        min_len = _min_password_length()

        if len(value) < min_len:
            raise ValueError(f"A senha deve ter pelo menos {min_len} caracteres")

        if len(value.encode("utf-8")) > 72:
            raise ValueError("A senha deve ter no máximo 72 bytes")

        if not any(char.isalpha() for char in value) or not any(char.isdigit() for char in value):
            raise ValueError("A senha deve combinar letras e números")

        return value


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    role: UserRole
    is_active: bool
    email_verified: bool

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    user: UserOut


class RegisterResponse(BaseModel):
    message: str
    user: UserOut


class MessageResponse(BaseModel):
    message: str


class ResendVerificationRequest(BaseModel):
    email: EmailStr