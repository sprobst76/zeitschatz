"""Kisi (Salfeld) provider - TAN-based rewards."""

from datetime import datetime
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.ledger import TanLedger
from app.models.tan_pool import TanPool
from app.services.providers.base import RewardProvider


class KisiProvider(RewardProvider):
    """Kisi provider for TAN-based screen time rewards.

    Uses a pre-imported pool of TAN codes from Salfeld Kisi.
    When a reward is approved, a TAN from the pool is assigned to the child.
    """

    code = "kisi"
    name = "Salfeld Kisi"
    requires_tan_pool = True

    async def approve_reward(
        self,
        db: Session,
        family_id: int,
        child_id: int,
        minutes: int,
        target_device: str,
        submission_id: int | None = None,
        tan_code: str | None = None,
        reason: str | None = None,
        **kwargs: Any,
    ) -> TanLedger:
        """Create reward with TAN code assignment.

        If tan_code is provided, uses that specific TAN.
        Otherwise, automatically assigns the next available TAN.
        """
        # If no TAN code provided, get next available from pool
        if not tan_code:
            next_tan = (
                db.query(TanPool)
                .filter(
                    TanPool.family_id == family_id,
                    TanPool.used == False,
                    TanPool.target_device == target_device,
                )
                .order_by(TanPool.created_at)
                .first()
            )
            if next_tan:
                tan_code = next_tan.tan_code
                # Mark TAN as used
                next_tan.used = True
                next_tan.used_at = datetime.utcnow()
                next_tan.used_by_child_id = child_id

        # Create ledger entry
        ledger_entry = TanLedger(
            child_id=child_id,
            submission_id=submission_id,
            minutes=minutes,
            target_device=target_device,
            tan_code=tan_code,
            reason=reason,
            family_id=family_id,
            provider_type=self.code,
            paid_out=False,
        )
        db.add(ledger_entry)
        db.commit()
        db.refresh(ledger_entry)

        return ledger_entry

    async def get_available_rewards(
        self,
        db: Session,
        family_id: int,
        target_device: str | None = None,
    ) -> list[dict[str, Any]]:
        """Get available TANs from the pool."""
        query = db.query(TanPool).filter(
            TanPool.family_id == family_id,
            TanPool.used == False,
        )

        if target_device:
            query = query.filter(TanPool.target_device == target_device)

        tans = query.order_by(TanPool.created_at).all()

        return [
            {
                "id": tan.id,
                "tan_code": tan.tan_code,
                "minutes": tan.minutes,
                "target_device": tan.target_device,
                "created_at": tan.created_at.isoformat(),
            }
            for tan in tans
        ]

    async def get_pending_payouts(
        self,
        db: Session,
        family_id: int,
        child_id: int | None = None,
        target_device: str | None = None,
    ) -> list[dict[str, Any]]:
        """Get unpaid TAN rewards grouped by child and device."""
        query = db.query(
            TanLedger.child_id,
            TanLedger.target_device,
            func.sum(TanLedger.minutes).label("total_minutes"),
            func.count(TanLedger.id).label("entry_count"),
        ).filter(
            TanLedger.family_id == family_id,
            TanLedger.provider_type == self.code,
            TanLedger.paid_out == False,
        )

        if child_id:
            query = query.filter(TanLedger.child_id == child_id)
        if target_device:
            query = query.filter(TanLedger.target_device == target_device)

        query = query.group_by(TanLedger.child_id, TanLedger.target_device)

        results = query.all()

        return [
            {
                "child_id": r.child_id,
                "target_device": r.target_device,
                "total_minutes": r.total_minutes,
                "entry_count": r.entry_count,
            }
            for r in results
        ]

    def get_approval_ui_config(self) -> dict[str, Any]:
        """Kisi needs TAN selector in approval UI."""
        return {
            "show_tan_selector": True,
            "show_minutes_input": True,
            "show_device_selector": True,
            "tan_auto_assign": True,  # Can auto-assign from pool
        }
