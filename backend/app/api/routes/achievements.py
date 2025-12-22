"""Achievement API routes."""
from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, require_role
from app.models.user import User
from app.services.achievements import (
    get_user_achievements,
    check_and_award_achievements,
    get_new_unlocked_achievements,
    seed_achievements,
)

router = APIRouter()


@router.get("")
def list_achievements(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db_session),
):
    """List all achievements with user's unlock status."""
    return get_user_achievements(db, user.id)


@router.get("/check")
def check_achievements(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db_session),
):
    """Check and award any newly unlocked achievements."""
    newly_unlocked = check_and_award_achievements(db, user.id)
    return {
        "newly_unlocked": [
            {
                "id": a.id,
                "code": a.code,
                "name": a.name,
                "description": a.description,
                "icon": a.icon,
                "reward_minutes": a.reward_minutes,
            }
            for a in newly_unlocked
        ]
    }


@router.get("/new")
def get_new_achievements(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db_session),
):
    """Get achievements that were just unlocked (for notifications)."""
    return get_new_unlocked_achievements(db, user.id)


@router.get("/child/{child_id}")
def get_child_achievements(
    child_id: int,
    user: User = Depends(require_role("parent")),
    db: Session = Depends(get_db_session),
):
    """Get achievements for a specific child (parent only)."""
    return get_user_achievements(db, child_id)


@router.post("/seed", dependencies=[Depends(require_role("parent"))])
def seed_achievement_definitions(
    db: Session = Depends(get_db_session),
):
    """Seed achievement definitions to database."""
    count = seed_achievements(db)
    return {"message": f"Seeded {count} new achievements"}
