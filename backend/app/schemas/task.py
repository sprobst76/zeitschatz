from typing import Any
from pydantic import BaseModel, Field

from app.schemas.common import ORMBase


class TaskBase(BaseModel):
    title: str
    description: str | None = None
    category: str | None = None
    duration_minutes: int = Field(default=30, ge=1)
    tan_reward: int = Field(default=30, ge=1)
    target_devices: list[str] | None = None  # ["phone", "pc", "console"]
    requires_photo: bool = False
    auto_approve: bool = False  # Automatisch genehmigen ohne Eltern-Bestätigung
    recurrence: dict[str, Any] | None = None
    assigned_children: list[int] | None = None


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    category: str | None = None
    duration_minutes: int | None = Field(default=None, ge=1)
    tan_reward: int | None = Field(default=None, ge=1)
    target_devices: list[str] | None = None
    requires_photo: bool | None = None
    auto_approve: bool | None = None
    recurrence: dict[str, Any] | None = None
    assigned_children: list[int] | None = None
    is_active: bool | None = None


class TaskRead(ORMBase):
    id: int
    title: str
    description: str | None
    category: str | None
    duration_minutes: int
    tan_reward: int | None = None
    target_devices: list[str] | None = None
    requires_photo: bool
    auto_approve: bool = False
    recurrence: dict[str, Any] | None
    assigned_children: list[int] | None
    is_active: bool


# Task Templates
class TaskTemplateBase(BaseModel):
    title: str
    description: str | None = None
    category: str | None = None
    duration_minutes: int = Field(default=30, ge=1)
    tan_reward: int = Field(default=30, ge=1)
    target_devices: list[str] | None = None
    requires_photo: bool = False
    auto_approve: bool = False
    icon: str | None = None


class TaskTemplateCreate(TaskTemplateBase):
    pass


class TaskTemplateRead(ORMBase):
    id: int
    title: str
    description: str | None
    category: str | None
    duration_minutes: int
    tan_reward: int
    target_devices: list[str] | None = None
    requires_photo: bool
    auto_approve: bool
    icon: str | None
    is_system: bool
