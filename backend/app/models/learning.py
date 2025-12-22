"""Learning exercise models."""
from sqlalchemy import Column, Integer, String, JSON, DateTime, ForeignKey, Boolean
from sqlalchemy.sql import func

from app.models.base import Base


class LearningSession(Base):
    """Tracks a child's learning session."""
    __tablename__ = "learning_sessions"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject = Column(String(50), nullable=False)  # math, english, german
    difficulty = Column(String(20), nullable=False)  # grade1, grade2, grade3, grade4, grade5plus
    total_questions = Column(Integer, default=10)
    correct_answers = Column(Integer, default=0)
    wrong_answers = Column(Integer, default=0)
    time_seconds = Column(Integer, nullable=True)
    completed = Column(Boolean, default=False)
    tan_reward = Column(Integer, nullable=True)  # Minutes earned
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    completed_at = Column(DateTime, nullable=True)


class LearningProgress(Base):
    """Tracks overall learning progress per child and subject."""
    __tablename__ = "learning_progress"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject = Column(String(50), nullable=False)
    difficulty = Column(String(20), nullable=False)
    total_attempted = Column(Integer, default=0)
    total_correct = Column(Integer, default=0)
    sessions_completed = Column(Integer, default=0)
    last_session_at = Column(DateTime, nullable=True)
