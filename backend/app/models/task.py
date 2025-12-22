from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text, JSON

from app.models.base import Base


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(50), nullable=True)
    duration_minutes = Column(Integer, nullable=False, default=30)  # Geschätzte Dauer
    tan_reward = Column(Integer, nullable=False, default=30)  # TAN-Belohnung in Minuten
    target_devices = Column(JSON, nullable=True)  # List: ["phone", "pc", "console"]
    requires_photo = Column(Boolean, default=False, nullable=False)
    auto_approve = Column(Boolean, default=False, nullable=False)  # Automatisch genehmigen
    recurrence = Column(JSON, nullable=True)  # e.g. {"mon": true, ...}
    assigned_children = Column(JSON, nullable=True)  # list of child user_ids
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class TaskTemplate(Base):
    """Predefined task templates for quick task creation."""
    __tablename__ = "task_templates"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(50), nullable=True)
    duration_minutes = Column(Integer, nullable=False, default=30)
    tan_reward = Column(Integer, nullable=False, default=30)
    target_devices = Column(JSON, nullable=True)
    requires_photo = Column(Boolean, default=False)
    auto_approve = Column(Boolean, default=False)
    icon = Column(String(50), nullable=True)  # Icon name for display
    is_system = Column(Boolean, default=False)  # System templates can't be deleted
    sort_order = Column(Integer, default=0)
