from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, require_role
from app.models.ledger import TanLedger
from app.models.user import User
from app.schemas.ledger import LedgerAggregateRead, LedgerEntryRead, PayoutRequest

router = APIRouter()


@router.get("/my", response_model=List[LedgerAggregateRead])
def my_ledger(db: Session = Depends(get_db_session), user: User = Depends(get_current_user)):
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
        .group_by(TanLedger.child_id, TanLedger.target_device)
        .order_by(TanLedger.target_device)
    )
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
def aggregate_unpaid(child_id: int | None = None, db: Session = Depends(get_db_session)):
    stmt = (
        select(
            TanLedger.child_id,
            TanLedger.target_device,
            func.sum(TanLedger.minutes).label("total_minutes"),
            func.count(TanLedger.id).label("entry_count"),
        )
        .where(TanLedger.paid_out.is_(False))
        .group_by(TanLedger.child_id, TanLedger.target_device)
        .order_by(TanLedger.child_id, TanLedger.target_device)
    )
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
def list_ledger(child_id: int, db: Session = Depends(get_db_session)):
    stmt = select(TanLedger).where(TanLedger.child_id == child_id).order_by(TanLedger.created_at.desc())
    return db.execute(stmt).scalars().all()


@router.post("/payout", response_model=LedgerEntryRead, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role("parent"))])
def payout_entry(request: PayoutRequest, db: Session = Depends(get_db_session)):
    entry = TanLedger(
        child_id=request.child_id,
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
def mark_paid(entry_id: int, db: Session = Depends(get_db_session)):
    entry = db.get(TanLedger, entry_id)
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entry not found")
    entry.paid_out = True
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry
