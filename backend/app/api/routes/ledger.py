from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session, get_user_family_ids, verify_family_access
from app.core.security import get_current_user, require_role
from app.models.ledger import TanLedger
from app.models.user import User
from app.schemas.ledger import LedgerAggregateRead, LedgerEntryRead, PayoutRequest

router = APIRouter()


@router.get("/my", response_model=List[LedgerAggregateRead])
def my_ledger(
    family_id: int | None = Query(default=None, description="Filter auf Familie"),
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """Kinder können ihren eigenen Ledger sehen."""
    stmt = (
        select(
            TanLedger.child_id,
            TanLedger.target_device,
            func.sum(TanLedger.minutes).label("total_minutes"),
            func.count(TanLedger.id).label("entry_count"),
        )
        .where(TanLedger.child_id == user.id)
        .where(TanLedger.paid_out.is_(False))
    )

    # Family filtering
    if family_id is not None:
        if not verify_family_access(db, user.id, family_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")
        stmt = stmt.where(TanLedger.family_id == family_id)
    else:
        user_family_ids = get_user_family_ids(db, user.id)
        if user_family_ids:
            stmt = stmt.where(TanLedger.family_id.in_(user_family_ids))
        else:
            stmt = stmt.where(TanLedger.family_id.is_(None))

    stmt = stmt.group_by(TanLedger.child_id, TanLedger.target_device).order_by(TanLedger.target_device)
    rows = db.execute(stmt).all()
    return [
        LedgerAggregateRead(
            child_id=row.child_id,
            target_device=row.target_device,
            total_minutes=row.total_minutes or 0,
            entry_count=row.entry_count or 0,
        )
        for row in rows
    ]


@router.get("/aggregate", response_model=List[LedgerAggregateRead], dependencies=[Depends(require_role("parent"))])
def aggregate_unpaid(
    family_id: int | None = Query(default=None, description="Filter auf Familie"),
    child_id: int | None = None,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    stmt = (
        select(
            TanLedger.child_id,
            TanLedger.target_device,
            func.sum(TanLedger.minutes).label("total_minutes"),
            func.count(TanLedger.id).label("entry_count"),
        )
        .where(TanLedger.paid_out.is_(False))
    )

    # Family filtering
    if family_id is not None:
        if not verify_family_access(db, user.id, family_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")
        stmt = stmt.where(TanLedger.family_id == family_id)
    else:
        user_family_ids = get_user_family_ids(db, user.id)
        if user_family_ids:
            stmt = stmt.where(TanLedger.family_id.in_(user_family_ids))
        else:
            stmt = stmt.where(TanLedger.family_id.is_(None))

    stmt = stmt.group_by(TanLedger.child_id, TanLedger.target_device).order_by(TanLedger.child_id, TanLedger.target_device)

    if child_id is not None:
        stmt = stmt.where(TanLedger.child_id == child_id)
    rows = db.execute(stmt).all()
    return [
        LedgerAggregateRead(
            child_id=row.child_id,
            target_device=row.target_device,
            total_minutes=row.total_minutes or 0,
            entry_count=row.entry_count or 0,
        )
        for row in rows
    ]


@router.get("/{child_id}", response_model=List[LedgerEntryRead], dependencies=[Depends(require_role("parent"))])
def list_ledger(
    child_id: int,
    family_id: int | None = Query(default=None, description="Filter auf Familie"),
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    stmt = select(TanLedger).where(TanLedger.child_id == child_id)

    # Family filtering
    if family_id is not None:
        if not verify_family_access(db, user.id, family_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")
        stmt = stmt.where(TanLedger.family_id == family_id)
    else:
        user_family_ids = get_user_family_ids(db, user.id)
        if user_family_ids:
            stmt = stmt.where(TanLedger.family_id.in_(user_family_ids))
        else:
            stmt = stmt.where(TanLedger.family_id.is_(None))

    stmt = stmt.order_by(TanLedger.created_at.desc())
    return db.execute(stmt).scalars().all()


@router.post("/payout", response_model=LedgerEntryRead, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role("parent"))])
def payout_entry(
    request: PayoutRequest,
    family_id: int = Query(..., description="Familie"),
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    # Verify family access
    if not verify_family_access(db, user.id, family_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")

    entry = TanLedger(
        child_id=request.child_id,
        family_id=family_id,
        submission_id=None,
        minutes=request.minutes,
        target_device=request.target_device,
        tan_code=request.tan_code,
        valid_until=request.valid_until,
        reason=request.reason or "manual payout",
        paid_out=True,
    )
    db.add(entry)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="TAN code already exists",
        )
    db.refresh(entry)
    return entry


@router.post("/{entry_id}/mark-paid", response_model=LedgerEntryRead, dependencies=[Depends(require_role("parent"))])
def mark_paid(
    entry_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    entry = db.get(TanLedger, entry_id)
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entry not found")

    # Verify family access
    if entry.family_id and not verify_family_access(db, user.id, entry.family_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diesen Eintrag")

    entry.paid_out = True
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry
