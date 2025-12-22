from datetime import datetime
from pydantic import BaseModel

from app.schemas.common import ORMBase


class TanPoolEntry(ORMBase):
    id: int
    tan_code: str
    minutes: int
    target_device: str
    created_at: datetime
    used: bool
    used_at: datetime | None
    used_by_child_id: int | None


class TanPoolImportLine(BaseModel):
    tan_code: str
    minutes: int
    target_device: str


class TanPoolImportRequest(BaseModel):
    """Import TANs from text format: TAN;Minutes;Created;Device"""
    raw_text: str


class TanPoolImportResponse(BaseModel):
    imported: int
    skipped: int
    errors: list[str]


class TanPoolStats(BaseModel):
    total: int
    available: int
    used: int
    by_device: dict[str, int]  # device -> available count
