from pydantic import BaseModel, EmailStr, Field, field_validator
import re


class LoginRequest(BaseModel):
    """PIN-based login (legacy, for children within family)."""
    user_id: int
    pin: str


class EmailLoginRequest(BaseModel):
    """Email/password login for parents."""
    email: EmailStr
    password: str = Field(..., min_length=8)


class PinLoginRequest(BaseModel):
    """PIN login with family context (for children)."""
    family_code: str = Field(..., min_length=6, max_length=16)
    user_id: int
    pin: str = Field(..., min_length=4, max_length=8)


class RegisterRequest(BaseModel):
    """Parent registration with email/password."""
    email: EmailStr
    password: str = Field(..., min_length=8)
    name: str = Field(..., min_length=2, max_length=100)

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Passwort muss mindestens 8 Zeichen haben")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Passwort muss mindestens einen Großbuchstaben enthalten")
        if not re.search(r"[a-z]", v):
            raise ValueError("Passwort muss mindestens einen Kleinbuchstaben enthalten")
        if not re.search(r"[0-9]", v):
            raise ValueError("Passwort muss mindestens eine Zahl enthalten")
        return v


class VerifyEmailRequest(BaseModel):
    """Email verification token."""
    token: str = Field(..., min_length=32, max_length=64)


class ForgotPasswordRequest(BaseModel):
    """Request password reset."""
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    """Complete password reset."""
    token: str = Field(..., min_length=32, max_length=64)
    new_password: str = Field(..., min_length=8)

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Passwort muss mindestens 8 Zeichen haben")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Passwort muss mindestens einen Großbuchstaben enthalten")
        if not re.search(r"[a-z]", v):
            raise ValueError("Passwort muss mindestens einen Kleinbuchstaben enthalten")
        if not re.search(r"[0-9]", v):
            raise ValueError("Passwort muss mindestens eine Zahl enthalten")
        return v


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"


class MessageResponse(BaseModel):
    """Simple message response."""
    message: str
    success: bool = True
