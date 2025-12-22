from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ORMBase

# Common weak PINs to reject
WEAK_PINS = {
    "0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999",
    "1234", "4321", "0123", "1230", "12345", "123456", "654321",
}


class UserRead(ORMBase):
    id: int
    name: str
    role: str
    is_active: bool
    allowed_devices: list[str] | None = None
    created_at: datetime


class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    role: Literal["parent", "child"]
    pin: str = Field(..., min_length=4, max_length=8, description="4-8 digit PIN")
    allowed_devices: list[str] | None = None  # ["phone", "pc", "console"]

    @field_validator("pin")
    @classmethod
    def validate_pin(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("PIN must contain only digits")
        if v in WEAK_PINS:
            raise ValueError("PIN is too common, please choose a stronger PIN")
        return v


class UserUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    pin: str | None = Field(None, min_length=4, max_length=8)
    allowed_devices: list[str] | None = None
    is_active: bool | None = None

    @field_validator("pin")
    @classmethod
    def validate_pin(cls, v: str | None) -> str | None:
        if v is None:
            return v
        if not v.isdigit():
            raise ValueError("PIN must contain only digits")
        if v in WEAK_PINS:
            raise ValueError("PIN is too common, please choose a stronger PIN")
        return v
