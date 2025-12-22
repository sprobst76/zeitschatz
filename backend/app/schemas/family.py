"""Pydantic schemas for family management."""

from datetime import datetime
from pydantic import BaseModel, Field


class FamilyCreate(BaseModel):
    """Create a new family."""
    name: str = Field(..., min_length=2, max_length=100)


class FamilyUpdate(BaseModel):
    """Update family details."""
    name: str | None = Field(None, min_length=2, max_length=100)


class FamilyRead(BaseModel):
    """Family response model."""
    id: int
    name: str
    invite_code: str | None
    invite_expires_at: datetime | None
    created_at: datetime
    is_active: bool
    member_count: int | None = None

    model_config = {"from_attributes": True}


class FamilyMemberRead(BaseModel):
    """Family member response."""
    id: int
    user_id: int
    user_name: str
    user_role: str  # parent | child
    role_in_family: str  # admin | parent | child
    joined_at: datetime

    model_config = {"from_attributes": True}


class AddChildRequest(BaseModel):
    """Add a child to the family."""
    name: str = Field(..., min_length=2, max_length=100)
    pin: str = Field(..., min_length=4, max_length=8, pattern=r"^\d+$")
    allowed_devices: list[str] | None = None


class DeviceProviderConfig(BaseModel):
    """Device provider configuration."""
    device_type: str  # phone | pc | tablet | console
    provider_type: str  # kisi | family_link | manual
    provider_settings: dict | None = None


class DeviceProviderRead(BaseModel):
    """Device provider response."""
    id: int
    device_type: str
    provider_type: str
    provider_settings: dict | None

    model_config = {"from_attributes": True}


class InviteCodeResponse(BaseModel):
    """Generated invite code."""
    invite_code: str
    expires_at: datetime


class JoinFamilyRequest(BaseModel):
    """Join a family with invite code."""
    invite_code: str = Field(..., min_length=6, max_length=16)


class ProviderInfo(BaseModel):
    """Available provider info."""
    code: str
    name: str
    description: str | None
    requires_tan_pool: bool
