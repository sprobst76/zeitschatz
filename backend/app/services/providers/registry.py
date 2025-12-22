"""Provider registry for managing reward provider instances."""

from typing import Type

from sqlalchemy.orm import Session

from app.models.device_provider import DeviceProvider, RewardProvider as RewardProviderModel
from app.services.providers.base import RewardProvider
from app.services.providers.kisi import KisiProvider
from app.services.providers.family_link import FamilyLinkProvider
from app.services.providers.manual import ManualProvider


class ProviderRegistry:
    """Registry for reward provider implementations.

    Manages provider instances and provides helper methods
    for getting the appropriate provider for a family/device.
    """

    _providers: dict[str, Type[RewardProvider]] = {
        "kisi": KisiProvider,
        "family_link": FamilyLinkProvider,
        "manual": ManualProvider,
    }

    _instances: dict[str, RewardProvider] = {}

    @classmethod
    def get(cls, provider_code: str) -> RewardProvider:
        """Get a provider instance by code.

        Args:
            provider_code: Provider code (kisi, family_link, manual)

        Returns:
            Provider instance

        Raises:
            ValueError: If provider code is unknown
        """
        if provider_code not in cls._providers:
            raise ValueError(f"Unknown provider: {provider_code}")

        # Lazy instantiation
        if provider_code not in cls._instances:
            cls._instances[provider_code] = cls._providers[provider_code]()

        return cls._instances[provider_code]

    @classmethod
    def get_for_device(
        cls,
        db: Session,
        family_id: int,
        device_type: str,
    ) -> RewardProvider:
        """Get the configured provider for a family's device.

        Args:
            db: Database session
            family_id: Family ID
            device_type: Device type (phone, pc, tablet, console)

        Returns:
            Provider instance for this device

        Raises:
            ValueError: If no provider configured for this device
        """
        config = (
            db.query(DeviceProvider)
            .filter(
                DeviceProvider.family_id == family_id,
                DeviceProvider.device_type == device_type,
            )
            .first()
        )

        if not config:
            # Default to manual if not configured
            return cls.get("manual")

        return cls.get(config.provider_type)

    @classmethod
    def list_available(cls, db: Session) -> list[dict]:
        """List all available providers from database.

        Args:
            db: Database session

        Returns:
            List of provider info dicts
        """
        providers = (
            db.query(RewardProviderModel)
            .filter(RewardProviderModel.is_active == True)
            .order_by(RewardProviderModel.sort_order)
            .all()
        )

        return [
            {
                "code": p.code,
                "name": p.name,
                "description": p.description,
                "requires_tan_pool": p.requires_tan_pool,
            }
            for p in providers
        ]

    @classmethod
    def register(cls, provider_class: Type[RewardProvider]) -> None:
        """Register a new provider class.

        Args:
            provider_class: Provider class to register
        """
        cls._providers[provider_class.code] = provider_class

    @classmethod
    def get_all_codes(cls) -> list[str]:
        """Get all registered provider codes.

        Returns:
            List of provider codes
        """
        return list(cls._providers.keys())
