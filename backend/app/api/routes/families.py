"""Family management API routes."""

import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.dependencies import get_db_session
from app.core.security import get_current_user, hash_pin, require_role
from app.models.device_provider import DeviceProvider, RewardProvider
from app.models.family import Family, FamilyMember
from app.models.user import User
from app.schemas.family import (
    AddChildRequest,
    DeviceProviderConfig,
    DeviceProviderRead,
    FamilyCreate,
    FamilyMemberRead,
    FamilyRead,
    FamilyUpdate,
    InviteCodeResponse,
    JoinFamilyRequest,
    ProviderInfo,
)
from app.services.email import get_email_service

router = APIRouter()
settings = get_settings()


def generate_invite_code() -> str:
    """Generate a random invite code."""
    return secrets.token_urlsafe(8).upper()[:12]


def get_family_or_404(db: Session, family_id: int, user: User) -> Family:
    """Get family and verify user is a member."""
    family = db.get(Family, family_id)
    if not family or not family.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Familie nicht gefunden")

    # Check membership
    membership = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user.id,
    ).first()
    if not membership:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")

    return family


def require_family_admin(db: Session, family_id: int, user: User) -> FamilyMember:
    """Verify user is admin of the family."""
    membership = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user.id,
    ).first()
    if not membership:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")
    if membership.role_in_family != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Nur Admins können diese Aktion ausführen")
    return membership


@router.post("/", response_model=FamilyRead)
def create_family(
    payload: FamilyCreate,
    db: Session = Depends(get_db_session),
    user: User = Depends(require_role("parent")),
):
    """Create a new family. The creating user becomes admin."""
    # Check if user's email is verified
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bitte verifiziere zuerst deine Email-Adresse",
        )

    # Generate invite code
    invite_code = generate_invite_code()
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.invite_code_expiry_days)

    # Create family
    family = Family(
        name=payload.name,
        invite_code=invite_code,
        invite_expires_at=expires_at,
    )
    db.add(family)
    db.flush()

    # Add user as admin
    membership = FamilyMember(
        family_id=family.id,
        user_id=user.id,
        role_in_family="admin",
    )
    db.add(membership)

    # Set up default device providers (all devices use 'manual' by default)
    for device in ["phone", "pc", "tablet", "console"]:
        provider = DeviceProvider(
            family_id=family.id,
            device_type=device,
            provider_type="manual",
        )
        db.add(provider)

    db.commit()
    db.refresh(family)

    return FamilyRead(
        id=family.id,
        name=family.name,
        invite_code=family.invite_code,
        invite_expires_at=family.invite_expires_at,
        created_at=family.created_at,
        is_active=family.is_active,
        member_count=1,
    )


@router.get("/", response_model=list[FamilyRead])
def list_families(
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """List all families the user belongs to."""
    memberships = db.query(FamilyMember).filter(FamilyMember.user_id == user.id).all()

    families = []
    for m in memberships:
        family = db.get(Family, m.family_id)
        if family and family.is_active:
            member_count = db.query(func.count(FamilyMember.id)).filter(
                FamilyMember.family_id == family.id
            ).scalar()
            families.append(FamilyRead(
                id=family.id,
                name=family.name,
                invite_code=family.invite_code if m.role_in_family == "admin" else None,
                invite_expires_at=family.invite_expires_at,
                created_at=family.created_at,
                is_active=family.is_active,
                member_count=member_count,
            ))

    return families


@router.get("/{family_id}", response_model=FamilyRead)
def get_family(
    family_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Get family details."""
    family = get_family_or_404(db, family_id, user)

    member_count = db.query(func.count(FamilyMember.id)).filter(
        FamilyMember.family_id == family.id
    ).scalar()

    # Check if user is admin to show invite code
    membership = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user.id,
    ).first()

    return FamilyRead(
        id=family.id,
        name=family.name,
        invite_code=family.invite_code if membership.role_in_family == "admin" else None,
        invite_expires_at=family.invite_expires_at,
        created_at=family.created_at,
        is_active=family.is_active,
        member_count=member_count,
    )


@router.patch("/{family_id}", response_model=FamilyRead)
def update_family(
    family_id: int,
    payload: FamilyUpdate,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Update family settings (admin only)."""
    require_family_admin(db, family_id, user)
    family = get_family_or_404(db, family_id, user)

    if payload.name is not None:
        family.name = payload.name

    db.commit()
    db.refresh(family)

    member_count = db.query(func.count(FamilyMember.id)).filter(
        FamilyMember.family_id == family.id
    ).scalar()

    return FamilyRead(
        id=family.id,
        name=family.name,
        invite_code=family.invite_code,
        invite_expires_at=family.invite_expires_at,
        created_at=family.created_at,
        is_active=family.is_active,
        member_count=member_count,
    )


@router.delete("/{family_id}")
def delete_family(
    family_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Deactivate a family (admin only)."""
    require_family_admin(db, family_id, user)
    family = get_family_or_404(db, family_id, user)

    family.is_active = False
    db.commit()

    return {"message": "Familie deaktiviert"}


# Members
@router.get("/{family_id}/members", response_model=list[FamilyMemberRead])
def list_members(
    family_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """List all members of a family."""
    get_family_or_404(db, family_id, user)

    memberships = db.query(FamilyMember).filter(FamilyMember.family_id == family_id).all()

    result = []
    for m in memberships:
        member_user = db.get(User, m.user_id)
        if member_user:
            result.append(FamilyMemberRead(
                id=m.id,
                user_id=member_user.id,
                user_name=member_user.name,
                user_role=member_user.role,
                role_in_family=m.role_in_family,
                joined_at=m.joined_at,
            ))

    return result


@router.post("/{family_id}/children", response_model=FamilyMemberRead)
def add_child(
    family_id: int,
    payload: AddChildRequest,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Add a child to the family (parent/admin only)."""
    membership = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user.id,
    ).first()
    if not membership or membership.role_in_family not in ["admin", "parent"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Keine Berechtigung")

    # Create child user
    child = User(
        name=payload.name,
        role="child",
        pin_hash=hash_pin(payload.pin),
        allowed_devices=payload.allowed_devices or ["phone", "pc", "tablet", "console"],
        is_active=True,
    )
    db.add(child)
    db.flush()

    # Add to family
    child_membership = FamilyMember(
        family_id=family_id,
        user_id=child.id,
        role_in_family="child",
    )
    db.add(child_membership)
    db.commit()
    db.refresh(child_membership)

    return FamilyMemberRead(
        id=child_membership.id,
        user_id=child.id,
        user_name=child.name,
        user_role=child.role,
        role_in_family=child_membership.role_in_family,
        joined_at=child_membership.joined_at,
    )


@router.delete("/{family_id}/members/{user_id}")
def remove_member(
    family_id: int,
    user_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Remove a member from the family (admin only)."""
    require_family_admin(db, family_id, user)

    if user_id == user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Du kannst dich nicht selbst entfernen")

    membership = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    ).first()
    if not membership:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Mitglied nicht gefunden")

    db.delete(membership)
    db.commit()

    return {"message": "Mitglied entfernt"}


# Invite
@router.post("/{family_id}/invite", response_model=InviteCodeResponse)
def generate_invite(
    family_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Generate a new invite code (admin only)."""
    require_family_admin(db, family_id, user)
    family = get_family_or_404(db, family_id, user)

    # Generate new code
    family.invite_code = generate_invite_code()
    family.invite_expires_at = datetime.now(timezone.utc) + timedelta(days=settings.invite_code_expiry_days)
    db.commit()

    return InviteCodeResponse(
        invite_code=family.invite_code,
        expires_at=family.invite_expires_at,
    )


@router.post("/join", response_model=FamilyRead)
def join_family(
    payload: JoinFamilyRequest,
    db: Session = Depends(get_db_session),
    user: User = Depends(require_role("parent")),
):
    """Join a family with invite code."""
    # Find family by invite code
    family = db.query(Family).filter(
        Family.invite_code == payload.invite_code,
        Family.is_active == True,
    ).first()

    if not family:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ungültiger Einladungscode")

    # Check expiration
    if family.invite_expires_at and family.invite_expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Einladungscode abgelaufen")

    # Check if already member
    existing = db.query(FamilyMember).filter(
        FamilyMember.family_id == family.id,
        FamilyMember.user_id == user.id,
    ).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Du bist bereits Mitglied dieser Familie")

    # Add as parent
    membership = FamilyMember(
        family_id=family.id,
        user_id=user.id,
        role_in_family="parent",
    )
    db.add(membership)
    db.commit()

    member_count = db.query(func.count(FamilyMember.id)).filter(
        FamilyMember.family_id == family.id
    ).scalar()

    return FamilyRead(
        id=family.id,
        name=family.name,
        invite_code=None,  # Don't show invite code to new members
        invite_expires_at=None,
        created_at=family.created_at,
        is_active=family.is_active,
        member_count=member_count,
    )


# Device Providers
@router.get("/{family_id}/devices", response_model=list[DeviceProviderRead])
def list_device_providers(
    family_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Get device provider configuration for family."""
    get_family_or_404(db, family_id, user)

    providers = db.query(DeviceProvider).filter(DeviceProvider.family_id == family_id).all()

    return [DeviceProviderRead(
        id=p.id,
        device_type=p.device_type,
        provider_type=p.provider_type,
        provider_settings=p.provider_settings,
    ) for p in providers]


@router.patch("/{family_id}/devices/{device_type}", response_model=DeviceProviderRead)
def update_device_provider(
    family_id: int,
    device_type: str,
    payload: DeviceProviderConfig,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Set provider for a device type (admin only)."""
    require_family_admin(db, family_id, user)

    # Validate device type
    if device_type not in ["phone", "pc", "tablet", "console"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ungültiger Gerätetyp")

    # Validate provider type
    valid_providers = db.query(RewardProvider).filter(
        RewardProvider.code == payload.provider_type,
        RewardProvider.is_active == True,
    ).first()
    if not valid_providers:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ungültiger Provider")

    # Find or create config
    config = db.query(DeviceProvider).filter(
        DeviceProvider.family_id == family_id,
        DeviceProvider.device_type == device_type,
    ).first()

    if config:
        config.provider_type = payload.provider_type
        config.provider_settings = payload.provider_settings
    else:
        config = DeviceProvider(
            family_id=family_id,
            device_type=device_type,
            provider_type=payload.provider_type,
            provider_settings=payload.provider_settings,
        )
        db.add(config)

    db.commit()
    db.refresh(config)

    return DeviceProviderRead(
        id=config.id,
        device_type=config.device_type,
        provider_type=config.provider_type,
        provider_settings=config.provider_settings,
    )


# Providers Registry
@router.get("/providers/available", response_model=list[ProviderInfo])
def list_available_providers(db: Session = Depends(get_db_session)):
    """List all available reward providers."""
    providers = db.query(RewardProvider).filter(RewardProvider.is_active == True).order_by(RewardProvider.sort_order).all()

    return [ProviderInfo(
        code=p.code,
        name=p.name,
        description=p.description,
        requires_tan_pool=p.requires_tan_pool,
    ) for p in providers]
