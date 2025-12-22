"""Abstract base class for reward providers."""

from abc import ABC, abstractmethod
from typing import Any

from sqlalchemy.orm import Session

from app.models.ledger import TanLedger


class RewardProvider(ABC):
    """Abstract base class for reward provider implementations.

    Each provider handles how rewards are tracked and distributed
    for a specific parental control system (Kisi, Family Link, etc.).
    """

    # Provider identification
    code: str  # Unique code: 'kisi', 'family_link', 'manual'
    name: str  # Display name
    requires_tan_pool: bool  # Whether this provider needs TAN pool

    @abstractmethod
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
        """Create a reward entry for an approved submission.

        Args:
            db: Database session
            family_id: Family ID for tenant isolation
            child_id: Child user ID receiving the reward
            minutes: Amount of screen time in minutes
            target_device: Device type (phone, pc, tablet, console)
            submission_id: Optional linked submission ID
            tan_code: Optional TAN code (for Kisi)
            reason: Optional reason/note
            **kwargs: Provider-specific arguments

        Returns:
            Created TanLedger entry
        """
        pass

    @abstractmethod
    async def get_available_rewards(
        self,
        db: Session,
        family_id: int,
        target_device: str | None = None,
    ) -> list[dict[str, Any]]:
        """Get available rewards for this provider.

        For Kisi: Returns available TANs from pool
        For Family Link: Returns empty (no pre-defined rewards)
        For Manual: Returns empty

        Args:
            db: Database session
            family_id: Family ID for tenant isolation
            target_device: Optional filter by device type

        Returns:
            List of available reward options
        """
        pass

    @abstractmethod
    async def get_pending_payouts(
        self,
        db: Session,
        family_id: int,
        child_id: int | None = None,
        target_device: str | None = None,
    ) -> list[dict[str, Any]]:
        """Get pending payouts (earned but not yet redeemed).

        Args:
            db: Database session
            family_id: Family ID for tenant isolation
            child_id: Optional filter by child
            target_device: Optional filter by device type

        Returns:
            List of pending payout summaries
        """
        pass

    def validate_settings(self, settings: dict[str, Any]) -> bool:
        """Validate provider-specific settings.

        Override in subclasses that require configuration.

        Args:
            settings: Provider settings dict

        Returns:
            True if valid, raises ValueError if invalid
        """
        return True

    def get_approval_ui_config(self) -> dict[str, Any]:
        """Get UI configuration for the approval dialog.

        Returns provider-specific UI hints for the frontend.

        Returns:
            Dict with UI configuration
        """
        return {
            "show_tan_selector": self.requires_tan_pool,
            "show_minutes_input": True,
            "show_device_selector": True,
        }
