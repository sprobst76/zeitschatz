import logging
from datetime import datetime, timedelta
from typing import List

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.submission import Submission
from app.models.user import User
from app.models.family import FamilyMember
from app.models.ledger import TanLedger
from app.services.photos import cleanup_expired, stream_photo

logger = logging.getLogger(__name__)


def clean_expired_photos(db: Session) -> List[str]:
    """
    Deletes expired photos based on photo_expires_at and storage mtime fallback.
    Returns list of removed file paths.
    """
    removed: List[str] = []
    now = datetime.utcnow()

    # Delete files whose DB entry is expired
    stmt = select(Submission).where(
        Submission.photo_path.isnot(None),
        Submission.photo_expires_at.isnot(None),
        Submission.photo_expires_at < now,
    )
    for sub in db.execute(stmt).scalars().all():
        try:
            # Ensure file exists before delete
            stream_photo(sub.photo_path)
        except Exception:
            pass  # ignore if already gone
        else:
            try:
                import os

                os.remove(sub.photo_path)
                removed.append(sub.photo_path)
            except OSError:
                pass
        sub.photo_path = None
        sub.photo_expires_at = None
        db.add(sub)

    # Fallback cleanup by mtime
    removed.extend(cleanup_expired(now))

    if removed:
        db.commit()
    return removed


def clean_inactive_users(db: Session, inactive_days: int = 90) -> List[str]:
    """
    Permanently delete users who haven't logged in for the specified number of days.
    Returns list of deleted user identifiers (name/email).

    NOTE: For future enhancement, consider sending warning email/notification
    before deletion (e.g., 7 days before).
    """
    deleted: List[str] = []
    cutoff_date = datetime.utcnow() - timedelta(days=inactive_days)

    # Find users who are inactive
    # A user is inactive if:
    # - last_login is older than cutoff_date, OR
    # - last_login is NULL AND created_at is older than cutoff_date
    stmt = select(User).where(
        User.is_active == True,
        (
            (User.last_login.isnot(None) & (User.last_login < cutoff_date)) |
            (User.last_login.is_(None) & (User.created_at < cutoff_date))
        )
    )

    inactive_users = db.execute(stmt).scalars().all()

    for user in inactive_users:
        user_info = f"{user.name} ({user.email or 'no email'})"

        try:
            # Delete associated data
            db.query(FamilyMember).filter(FamilyMember.user_id == user.id).delete()
            db.query(Submission).filter(Submission.child_id == user.id).delete()
            db.query(TanLedger).filter(TanLedger.child_id == user.id).delete()

            # Delete the user
            db.delete(user)
            deleted.append(user_info)
            logger.info(f"[retention] Deleted inactive user: {user_info} (last_login: {user.last_login}, created: {user.created_at})")

        except Exception as e:
            logger.error(f"[retention] Failed to delete user {user_info}: {e}")

    if deleted:
        db.commit()

    return deleted
