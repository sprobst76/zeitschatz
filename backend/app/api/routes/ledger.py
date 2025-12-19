from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import require_role
from app.models.ledger import TanLedger
from app.schemas.ledger import LedgerEntryRead, PayoutRequest

router = APIRouter()


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
    db.commit()
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
