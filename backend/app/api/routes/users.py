from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import hash_pin, require_role
from app.models.user import User
from app.schemas.user import UserCreate, UserRead, UserUpdate

router = APIRouter()


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


@router.get("", response_model=List[UserRead], dependencies=[Depends(require_role("parent"))])
def list_users(db: Session = Depends(get_db_session)):
    """List all users (parent-only)."""
    stmt = select(User).where(User.is_active.is_(True)).order_by(User.name)
    return db.execute(stmt).scalars().all()


@router.get("/children", response_model=List[UserRead], dependencies=[Depends(require_role("parent"))])
def list_children(db: Session = Depends(get_db_session)):
    """List all child users (parent-only)."""
    stmt = select(User).where(User.role == "child", User.is_active.is_(True)).order_by(User.name)
    return db.execute(stmt).scalars().all()


@router.get("/{user_id}", response_model=UserRead, dependencies=[Depends(require_role("parent"))])
def get_user(user_id: int, db: Session = Depends(get_db_session)):
    """Get a single user by ID (parent-only)."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.patch("/{user_id}", response_model=UserRead, dependencies=[Depends(require_role("parent"))])
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(get_db_session)):
    """Update a user (parent-only). Only provided fields are updated."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
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
def deactivate_user(user_id: int, db: Session = Depends(get_db_session)):
    """Deactivate a user (soft delete, parent-only)."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.is_active = False
    db.add(user)
    db.commit()
