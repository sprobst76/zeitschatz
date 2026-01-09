from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, hash_pin, require_role
from app.models.user import User
from app.models.family import FamilyMember
from app.schemas.user import UserCreate, UserRead, UserUpdate

router = APIRouter()


def get_user_family_ids(db: Session, user_id: int) -> list[int]:
    """Get all family IDs the user belongs to."""
    memberships = db.query(FamilyMember).filter(FamilyMember.user_id == user_id).all()
    return [m.family_id for m in memberships]


def get_family_member_ids(db: Session, family_ids: list[int]) -> set[int]:
    """Get all user IDs that are members of the given families."""
    if not family_ids:
        return set()
    memberships = db.query(FamilyMember).filter(FamilyMember.family_id.in_(family_ids)).all()
    return {m.user_id for m in memberships}


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role("parent"))])
def create_user(payload: UserCreate, db: Session = Depends(get_db_session)):
    """Create a new user (parent-only)."""
    user = User(
        name=payload.name,
        role=payload.role,
        pin_hash=hash_pin(payload.pin),
        allowed_devices=payload.allowed_devices,
        is_active=True,
        created_at=datetime.utcnow(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("", response_model=List[UserRead])
def list_users(
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
):
    """List users in the same family as the current user."""
    family_ids = get_user_family_ids(db, current_user.id)
    member_ids = get_family_member_ids(db, family_ids)

    if not member_ids:
        # User has no family - return only themselves
        return [current_user] if current_user.is_active else []

    stmt = select(User).where(
        User.id.in_(member_ids),
        User.is_active.is_(True)
    ).order_by(User.name)
    return db.execute(stmt).scalars().all()


@router.get("/children", response_model=List[UserRead])
def list_children(
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
):
    """List child users in the same family as the current user."""
    family_ids = get_user_family_ids(db, current_user.id)
    member_ids = get_family_member_ids(db, family_ids)

    if not member_ids:
        return []

    stmt = select(User).where(
        User.id.in_(member_ids),
        User.role == "child",
        User.is_active.is_(True)
    ).order_by(User.name)
    return db.execute(stmt).scalars().all()


@router.get("/{user_id}", response_model=UserRead)
def get_user(
    user_id: int,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
):
    """Get a single user by ID (must be in same family)."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Check if target user is in same family
    family_ids = get_user_family_ids(db, current_user.id)
    member_ids = get_family_member_ids(db, family_ids)
    if user_id not in member_ids and user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    return user


@router.patch("/{user_id}", response_model=UserRead, dependencies=[Depends(require_role("parent"))])
def update_user(
    user_id: int,
    payload: UserUpdate,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
):
    """Update a user (parent-only, must be in same family)."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Check if target user is in same family
    family_ids = get_user_family_ids(db, current_user.id)
    member_ids = get_family_member_ids(db, family_ids)
    if user_id not in member_ids:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    if payload.name is not None:
        user.name = payload.name
    if payload.pin is not None:
        user.pin_hash = hash_pin(payload.pin)
    if payload.allowed_devices is not None:
        user.allowed_devices = payload.allowed_devices
    if payload.is_active is not None:
        user.is_active = payload.is_active
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(require_role("parent"))])
def deactivate_user(
    user_id: int,
    db: Session = Depends(get_db_session),
    current_user: User = Depends(get_current_user),
):
    """Deactivate a user (soft delete, parent-only, must be in same family)."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Check if target user is in same family
    family_ids = get_user_family_ids(db, current_user.id)
    member_ids = get_family_member_ids(db, family_ids)
    if user_id not in member_ids:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    user.is_active = False
    db.add(user)
    db.commit()
