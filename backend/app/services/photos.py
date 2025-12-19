import os
import uuid
from datetime import datetime, timedelta
from pathlib import Path

from fastapi import HTTPException, UploadFile, status

from app.core.config import get_settings

settings = get_settings()


def ensure_storage_dir():
    Path(settings.storage_dir).mkdir(parents=True, exist_ok=True)


def save_photo(child_id: int, submission_id: int, file: UploadFile) -> tuple[str, datetime]:
    ensure_storage_dir()
    data = file.file.read(settings.photo_max_bytes + 1)
    if len(data) > settings.photo_max_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Photo too large")

    child_folder = Path(settings.storage_dir) / str(child_id)
    child_folder.mkdir(parents=True, exist_ok=True)
    fname = f"{submission_id}_{uuid.uuid4().hex}.jpg"
    path = child_folder / fname
    with open(path, "wb") as f:
        f.write(data)
    expires_at = datetime.utcnow() + timedelta(days=settings.photo_retention_days)
    return str(path), expires_at


def stream_photo(path: str):
    if not path or not os.path.exists(path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo not found")
    return Path(path).read_bytes()


def cleanup_expired(now: datetime | None = None) -> list[str]:
    """Delete files older than retention based on mtime as fallback."""
    now = now or datetime.utcnow()
    removed = []
    base = Path(settings.storage_dir)
    if not base.exists():
        return removed
    cutoff = now - timedelta(days=settings.photo_retention_days)
    for file in base.rglob("*.jpg"):
        mtime = datetime.utcfromtimestamp(file.stat().st_mtime)
        if mtime < cutoff:
            file.unlink(missing_ok=True)
            removed.append(str(file))
    return removed
