from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Text, JSON, UniqueConstraint
from sqlalchemy.orm import relationship

from app.models.base import Base


class DeviceProvider(Base):
    """Provider configuration per device type for a family.

    Each family can use different providers for different devices:
    - PC: Kisi (TAN-based)
    - Phone: Family Link (manual time tracking)
    - Tablet: Kisi
    - Console: Manual
    """

    __tablename__ = "device_providers"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False, index=True)
    device_type = Column(String(20), nullable=False)  # phone | pc | tablet | console
    provider_type = Column(String(30), nullable=False)  # kisi | family_link | manual
    provider_settings = Column(JSON, nullable=True)  # Provider-specific configuration

    __table_args__ = (UniqueConstraint("family_id", "device_type", name="uq_family_device"),)

    # Relationships
    family = relationship("Family", back_populates="device_providers")


class RewardProvider(Base):
    """Registry of available reward provider modules.

    System table with predefined provider types.
    """

    __tablename__ = "reward_providers"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(30), unique=True, nullable=False, index=True)  # kisi | family_link | manual
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    requires_tan_pool = Column(Boolean, default=False, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    sort_order = Column(Integer, default=0, nullable=False)
