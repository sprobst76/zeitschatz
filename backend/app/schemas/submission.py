from datetime import datetime
from pydantic import BaseModel

from app.schemas.common import ORMBase


class SubmissionCreate(BaseModel):
    task_id: int
    selected_device: str | None = None  # Device child chose for TAN
    comment: str | None = None
    photo_path: str | None = None


class SubmissionRead(ORMBase):
    id: int
    task_id: int
    child_id: int
    status: str
    selected_device: str | None = None
    comment: str | None
    photo_path: str | None
    created_at: datetime
    updated_at: datetime


class SubmissionReadExtended(SubmissionRead):
    """Erweiterte Submission mit Task- und Kind-Details."""
    task_title: str | None = None
    task_description: str | None = None
    child_name: str | None = None
    tan_reward: int | None = None
    target_devices: list[str] | None = None


class SubmissionDecision(BaseModel):
    minutes: int | None = None
    tan_code: str | None = None
    valid_until: datetime | None = None
    comment: str | None = None
