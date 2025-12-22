"""Achievement and badge models."""
from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.sql import func

from app.models.base import Base


class Achievement(Base):
    """Definition of an achievement/badge."""
    __tablename__ = "achievements"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), unique=True, nullable=False)  # e.g., "streak_7", "tasks_10"
    name = Column(String(100), nullable=False)  # Display name
    description = Column(Text, nullable=True)
    icon = Column(String(50), nullable=False, default="star")  # Icon name
    category = Column(String(50), nullable=False, default="general")  # streak, tasks, learning, special
    threshold = Column(Integer, nullable=True)  # e.g., 7 for "7-day streak"
    reward_minutes = Column(Integer, nullable=True)  # Bonus TAN minutes
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)


class UserAchievement(Base):
    """Tracks which achievements a user has unlocked."""
    __tablename__ = "user_achievements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    achievement_id = Column(Integer, ForeignKey("achievements.id", ondelete="CASCADE"), nullable=False)
    unlocked_at = Column(DateTime, server_default=func.now(), nullable=False)
    notified = Column(Boolean, default=False)  # Whether user was notified
