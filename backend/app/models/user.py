from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, Integer, String, JSON
from sqlalchemy.orm import relationship

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    role = Column(String(20), nullable=False)  # parent | child
    pin_hash = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    allowed_devices = Column(JSON, nullable=True)  # List of device types: ["phone", "pc", "console"]
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    device_tokens = relationship("DeviceToken", back_populates="user", cascade="all, delete-orphan")
