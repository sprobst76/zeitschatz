from datetime import datetime
from pydantic import BaseModel

from app.schemas.common import ORMBase


class LedgerEntryRead(ORMBase):
    id: int
    child_id: int
    submission_id: int | None
    minutes: int
    target_device: str | None
    tan_code: str | None
    valid_until: datetime | None
    reason: str | None
    paid_out: bool
    created_at: datetime


class PayoutRequest(BaseModel):
    child_id: int
    minutes: int
    target_device: str
    tan_code: str | None = None
    valid_until: datetime | None = None
    reason: str | None = None


class LedgerAggregateRead(BaseModel):
    child_id: int
    target_device: str | None
    total_minutes: int
    entry_count: int
