from datetime import datetime
from pydantic import BaseModel

from app.schemas.common import ORMBase


class SubmissionCreate(BaseModel):
    task_id: int
    comment: str | None = None
    photo_path: str | None = None


class SubmissionRead(ORMBase):
    id: int
    task_id: int
    child_id: int
    status: str
    comment: str | None
    photo_path: str | None
    created_at: datetime
    updated_at: datetime


class SubmissionDecision(BaseModel):
    minutes: int | None = None
    target_device: str | None = None
    tan_code: str | None = None
    valid_until: datetime | None = None
    comment: str | None = None
