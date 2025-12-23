from fastapi import Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.session import get_db


def get_db_session(db=Depends(get_db)):
    return db


def verify_family_access(db: Session, user_id: int, family_id: int) -> bool:
    """Check if user is a member of the specified family."""
    from app.models.family import FamilyMember

    membership = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    ).first()
    return membership is not None


def get_user_family_ids(db: Session, user_id: int) -> list[int]:
    """Get all family IDs the user belongs to."""
    from app.models.family import FamilyMember

    memberships = db.query(FamilyMember).filter(FamilyMember.user_id == user_id).all()
    return [m.family_id for m in memberships]


def require_family_access(
    family_id: int = Query(..., description="Family ID"),
    db: Session = Depends(get_db),
):
    """Dependency that requires family_id and validates access."""
    from app.core.security import get_current_user

    # This is a factory that returns the actual dependency
    def _check(user=Depends(get_current_user)):
        if not verify_family_access(db, user.id, family_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Kein Zugriff auf diese Familie",
            )
        return family_id

    return _check
