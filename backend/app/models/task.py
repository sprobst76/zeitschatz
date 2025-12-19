from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text, JSON

from app.models.base import Base


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(50), nullable=True)
    duration_minutes = Column(Integer, nullable=False, default=30)  # z. B. 30min oder 60min
    target_device = Column(String(50), nullable=True)  # z. B. phone | pc | tablet
    requires_photo = Column(Boolean, default=False, nullable=False)
    recurrence = Column(JSON, nullable=True)  # e.g. {"mon": true, ...}
    assigned_children = Column(JSON, nullable=True)  # list of child user_ids
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
