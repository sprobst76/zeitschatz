from typing import Any
from pydantic import BaseModel, Field

from app.schemas.common import ORMBase


class TaskBase(BaseModel):
    title: str
    description: str | None = None
    category: str | None = None
    duration_minutes: int = Field(default=30, ge=1)
    target_device: str | None = None
    requires_photo: bool = False
    recurrence: dict[str, Any] | None = None
    assigned_children: list[int] | None = None


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    category: str | None = None
    duration_minutes: int | None = Field(default=None, ge=1)
    target_device: str | None = None
    requires_photo: bool | None = None
    recurrence: dict[str, Any] | None = None
    assigned_children: list[int] | None = None
    is_active: bool | None = None


class TaskRead(ORMBase):
    id: int
    title: str
    description: str | None
    category: str | None
    duration_minutes: int
    target_device: str | None
    requires_photo: bool
    recurrence: dict[str, Any] | None
    assigned_children: list[int] | None
    is_active: bool
