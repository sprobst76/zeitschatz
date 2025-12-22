"""Manual provider - simple time tracking without external system."""

from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.ledger import TanLedger
from app.services.providers.base import RewardProvider


class ManualProvider(RewardProvider):
    """Manual provider for simple time tracking.

    No external system integration - just tracks earned time.
    Useful for families that manage screen time manually.
    """

    code = "manual"
    name = "Manuell"
    requires_tan_pool = False

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
        """Create reward entry for manual tracking."""
        ledger_entry = TanLedger(
            child_id=child_id,
            submission_id=submission_id,
            minutes=minutes,
            target_device=target_device,
            tan_code=None,
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
        """No pre-defined rewards for manual tracking."""
        return []

    async def get_pending_payouts(
        self,
        db: Session,
        family_id: int,
        child_id: int | None = None,
        target_device: str | None = None,
    ) -> list[dict[str, Any]]:
        """Get unpaid time rewards grouped by child and device."""
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
        """Simple approval UI for manual tracking."""
        return {
            "show_tan_selector": False,
            "show_minutes_input": True,
            "show_device_selector": True,
        }
