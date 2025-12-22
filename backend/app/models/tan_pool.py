from datetime import datetime
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Boolean
from sqlalchemy.orm import relationship

from app.models.base import Base


class TanPool(Base):
    __tablename__ = "tan_pool"

    id = Column(Integer, primary_key=True, index=True)
    tan_code = Column(String(12), unique=True, nullable=False, index=True)
    minutes = Column(Integer, nullable=False)  # Dauer in Minuten
    target_device = Column(String(50), nullable=False)  # Gerätebindung
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    used = Column(Boolean, default=False, nullable=False)
    used_at = Column(DateTime, nullable=True)
    used_by_child_id = Column(Integer, nullable=True)  # Welches Kind hat die TAN bekommen

    # Multi-family support
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=True, index=True)
    family = relationship("Family", back_populates="tan_pool")
