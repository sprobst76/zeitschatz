from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.common import ORMBase


class UserRead(ORMBase):
    id: int
    name: str
    role: str
    is_active: bool
    created_at: datetime


class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    role: Literal["parent", "child"]
    pin: str = Field(..., min_length=4, max_length=8, description="4-8 digit PIN")
