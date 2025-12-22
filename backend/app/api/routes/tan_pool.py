from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import require_role
from app.models.tan_pool import TanPool
from app.schemas.tan_pool import (
    TanPoolEntry,
    TanPoolImportRequest,
    TanPoolImportResponse,
    TanPoolStats,
)

router = APIRouter()


def normalize_device_name(device: str) -> str:
    """Normalize device names to standard format."""
    device = device.strip().lower()
    # Map common variations
    if "laptop" in device or "pc" in device or "computer" in device:
        return "pc"
    if "tablet" in device or "ipad" in device:
        return "tablet"
    if "phone" in device or "handy" in device or "smartphone" in device:
        return "phone"
    return device


@router.post("/import", response_model=TanPoolImportResponse, dependencies=[Depends(require_role("parent"))])
def import_tans(request: TanPoolImportRequest, db: Session = Depends(get_db_session)):
    """
    Import TANs from text format.
    Expected format per line: TAN;Minutes;Created;Device
    First line can be a header and will be skipped if it contains 'TAN' or 'Tan'.
    """
    lines = request.raw_text.strip().split("\n")
    imported = 0
    skipped = 0
    errors: list[str] = []

    for i, line in enumerate(lines, 1):
        line = line.strip()
        if not line:
            continue

        # Skip header line
        if i == 1 and ("TAN" in line.upper() or "MINUTES" in line.upper()):
            continue

        parts = line.split(";")
        if len(parts) < 4:
            errors.append(f"Zeile {i}: Ungültiges Format (erwartet TAN;Minutes;Created;Device)")
            continue

        tan_code = parts[0].strip()
        try:
            minutes = int(parts[1].strip())
        except ValueError:
            errors.append(f"Zeile {i}: Ungültige Minuten '{parts[1]}'")
            continue

        # parts[2] is Created date - we'll use current time instead
        device_raw = parts[3].strip().rstrip("#")  # Remove trailing #
        target_device = normalize_device_name(device_raw)

        # Check for duplicate
        existing = db.execute(
            select(TanPool).where(TanPool.tan_code == tan_code)
        ).scalar_one_or_none()

        if existing:
            skipped += 1
            continue

        entry = TanPool(
            tan_code=tan_code,
            minutes=minutes,
            target_device=target_device,
            created_at=datetime.utcnow(),
            used=False,
        )
        db.add(entry)
        imported += 1

    try:
        db.commit()
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Datenbank-Fehler: {str(e)}",
        )

    return TanPoolImportResponse(imported=imported, skipped=skipped, errors=errors)


@router.get("/", response_model=list[TanPoolEntry], dependencies=[Depends(require_role("parent"))])
def list_tans(
    available_only: bool = False,
    target_device: str | None = None,
    db: Session = Depends(get_db_session),
):
    """List all TANs in the pool, optionally filtered."""
    stmt = select(TanPool).order_by(TanPool.created_at.desc())

    if available_only:
        stmt = stmt.where(TanPool.used.is_(False))

    if target_device:
        stmt = stmt.where(TanPool.target_device == target_device.lower())

    return db.execute(stmt).scalars().all()


@router.get("/stats", response_model=TanPoolStats, dependencies=[Depends(require_role("parent"))])
def get_stats(db: Session = Depends(get_db_session)):
    """Get statistics about the TAN pool."""
    total = db.execute(select(func.count(TanPool.id))).scalar() or 0
    available = db.execute(
        select(func.count(TanPool.id)).where(TanPool.used.is_(False))
    ).scalar() or 0
    used = total - available

    # Count available by device
    device_counts = db.execute(
        select(TanPool.target_device, func.count(TanPool.id))
        .where(TanPool.used.is_(False))
        .group_by(TanPool.target_device)
    ).all()

    by_device = {row[0]: row[1] for row in device_counts}

    return TanPoolStats(
        total=total,
        available=available,
        used=used,
        by_device=by_device,
    )


@router.get("/next", response_model=TanPoolEntry | None, dependencies=[Depends(require_role("parent"))])
def get_next_available(target_device: str, db: Session = Depends(get_db_session)):
    """Get the next available TAN for a specific device."""
    stmt = (
        select(TanPool)
        .where(TanPool.used.is_(False))
        .where(TanPool.target_device == target_device.lower())
        .order_by(TanPool.created_at.asc())
        .limit(1)
    )
    return db.execute(stmt).scalar_one_or_none()


@router.post("/{tan_id}/use", response_model=TanPoolEntry, dependencies=[Depends(require_role("parent"))])
def mark_used(tan_id: int, child_id: int | None = None, db: Session = Depends(get_db_session)):
    """Mark a TAN as used."""
    entry = db.get(TanPool, tan_id)
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="TAN nicht gefunden")

    if entry.used:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="TAN bereits verwendet")

    entry.used = True
    entry.used_at = datetime.utcnow()
    entry.used_by_child_id = child_id
    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/{tan_id}", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(require_role("parent"))])
def delete_tan(tan_id: int, db: Session = Depends(get_db_session)):
    """Delete a TAN from the pool."""
    entry = db.get(TanPool, tan_id)
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="TAN nicht gefunden")

    db.delete(entry)
    db.commit()
