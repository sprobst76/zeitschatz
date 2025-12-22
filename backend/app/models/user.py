from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, Integer, String, JSON
from sqlalchemy.orm import relationship

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    role = Column(String(20), nullable=False)  # parent | child
    pin_hash = Column(String(255), nullable=True)  # NULL for email-only parents
    is_active = Column(Boolean, default=True, nullable=False)
    allowed_devices = Column(JSON, nullable=True)  # List of device types: ["phone", "pc", "console"]
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Email/Password auth (for parents)
    email = Column(String(255), unique=True, nullable=True, index=True)
    password_hash = Column(String(255), nullable=True)  # bcrypt hash, NULL for PIN-only children
    email_verified = Column(Boolean, default=False, nullable=False)
    verification_token = Column(String(64), nullable=True)
    reset_token = Column(String(64), nullable=True)
    reset_expires_at = Column(DateTime, nullable=True)

    # Relationships
    device_tokens = relationship("DeviceToken", back_populates="user", cascade="all, delete-orphan")
    family_memberships = relationship("FamilyMember", back_populates="user", cascade="all, delete-orphan")
