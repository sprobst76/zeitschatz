from datetime import datetime
from typing import List

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.submission import Submission
from app.services.photos import cleanup_expired, stream_photo


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
