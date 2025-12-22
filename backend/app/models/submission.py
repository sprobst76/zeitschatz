from datetime import datetime
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text

from app.models.base import Base


class Submission(Base):
    __tablename__ = "submissions"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    child_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    selected_device = Column(String(50), nullable=True)  # Device child chose for TAN
    comment = Column(Text, nullable=True)
    photo_path = Column(String(255), nullable=True)
    photo_expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)
