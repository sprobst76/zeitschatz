"""
Seeding script to create a test family with parent, children, and sample data.

Usage:
  # Create default test family
  python backend/scripts/seed_family.py

  # Custom family name
  python backend/scripts/seed_family.py --family "Mustermann"

  # Custom parent
  python backend/scripts/seed_family.py --parent-email "test@example.com" --parent-password "geheim123"

  # Multiple children
  python backend/scripts/seed_family.py --children "Max:1234:TIGER-ROT,Anna:5678:KATZE-BLAU"

  # With sample tasks
  python backend/scripts/seed_family.py --with-tasks

  # Full example
  python backend/scripts/seed_family.py \\
    --family "Testfamilie" \\
    --parent-name "Mama" \\
    --parent-email "mama@test.de" \\
    --parent-password "test1234" \\
    --children "Max:1111:MAX-CODE,Lisa:2222:LISA-CODE" \\
    --provider-pc kisi \\
    --provider-phone family_link \\
    --with-tasks
"""
import argparse
import secrets
from datetime import datetime, timedelta, timezone

from app.core.security import hash_password, hash_pin
from app.db.session import SessionLocal
from app.models.user import User
from app.models.family import Family, FamilyMember
from app.models.device_provider import DeviceProvider, RewardProvider
from app.models.task import Task


def generate_invite_code() -> str:
    """Generate a random invite code."""
    return secrets.token_urlsafe(8).upper()[:12]


def generate_login_code(name: str) -> str:
    """Generate a memorable login code from name."""
    adjectives = ["ROT", "BLAU", "GRUEN", "GELB", "ROSA", "LILA"]
    number = secrets.randbelow(100)
    adj = secrets.choice(adjectives)
    return f"{name.upper()}-{adj}-{number:02d}"


def seed_family(
    family_name: str = "Testfamilie",
    parent_name: str = "Eltern",
    parent_email: str = "test@zeitschatz.local",
    parent_password: str = "test1234",
    children_spec: str = "Kind:0000",
    provider_pc: str = "kisi",
    provider_phone: str = "manual",
    provider_tablet: str = "manual",
    provider_console: str = "manual",
    with_tasks: bool = False,
):
    db = SessionLocal()
    try:
        # Check if family already exists
        existing_family = db.query(Family).filter(Family.name == family_name).first()
        if existing_family:
            print(f"Familie '{family_name}' existiert bereits (id={existing_family.id})")
            print(f"  Invite-Code: {existing_family.invite_code}")
            return

        # Create family
        invite_code = generate_invite_code()
        family = Family(
            name=family_name,
            invite_code=invite_code,
            invite_expires_at=datetime.now(timezone.utc) + timedelta(days=365),
            is_active=True,
        )
        db.add(family)
        db.flush()
        print(f"\n=== Familie erstellt ===")
        print(f"  Name: {family_name}")
        print(f"  ID: {family.id}")
        print(f"  Invite-Code: {invite_code}")

        # Create parent
        existing_parent = db.query(User).filter(User.email == parent_email).first()
        if existing_parent:
            parent = existing_parent
            print(f"\nElternteil existiert bereits: {parent.name} (id={parent.id})")
        else:
            parent = User(
                name=parent_name,
                email=parent_email,
                password_hash=hash_password(parent_password),
                pin_hash="",  # No PIN for email-auth parents
                role="parent",
                email_verified=True,  # Auto-verified for testing
                is_active=True,
            )
            db.add(parent)
            db.flush()
            print(f"\n=== Elternteil erstellt ===")
            print(f"  Name: {parent_name}")
            print(f"  Email: {parent_email}")
            print(f"  Passwort: {parent_password}")
            print(f"  ID: {parent.id}")

        # Add parent as admin to family
        membership = FamilyMember(
            family_id=family.id,
            user_id=parent.id,
            role_in_family="admin",
        )
        db.add(membership)

        # Create children
        print(f"\n=== Kinder erstellt ===")
        child_ids = []
        for child_spec in children_spec.split(","):
            parts = child_spec.strip().split(":")
            child_name = parts[0]
            child_pin = parts[1] if len(parts) > 1 else "0000"
            child_code = parts[2] if len(parts) > 2 else generate_login_code(child_name)

            # Check if child with this login_code exists
            existing_child = db.query(User).filter(User.login_code == child_code).first()
            if existing_child:
                print(f"  Kind mit Code {child_code} existiert bereits")
                child_ids.append(existing_child.id)
                continue

            child = User(
                name=child_name,
                role="child",
                pin_hash=hash_pin(child_pin),
                login_code=child_code,
                allowed_devices=["phone", "pc", "tablet", "console"],
                is_active=True,
            )
            db.add(child)
            db.flush()

            # Add child to family
            child_membership = FamilyMember(
                family_id=family.id,
                user_id=child.id,
                role_in_family="child",
            )
            db.add(child_membership)
            child_ids.append(child.id)

            print(f"  {child_name}:")
            print(f"    ID: {child.id}")
            print(f"    PIN: {child_pin}")
            print(f"    Login-Code: {child_code}")

        # Set up device providers
        print(f"\n=== Device Provider ===")
        providers = {
            "pc": provider_pc,
            "phone": provider_phone,
            "tablet": provider_tablet,
            "console": provider_console,
        }
        for device, provider_type in providers.items():
            # Verify provider exists
            provider = db.query(RewardProvider).filter(RewardProvider.code == provider_type).first()
            if not provider:
                print(f"  WARNUNG: Provider '{provider_type}' nicht gefunden, nutze 'manual'")
                provider_type = "manual"

            device_provider = DeviceProvider(
                family_id=family.id,
                device_type=device,
                provider_type=provider_type,
            )
            db.add(device_provider)
            print(f"  {device}: {provider_type}")

        # Create sample tasks if requested
        if with_tasks and child_ids:
            print(f"\n=== Beispiel-Aufgaben erstellt ===")
            sample_tasks = [
                {
                    "title": "Zimmer aufraeumen",
                    "description": "Spielzeug wegräumen und Bett machen",
                    "tan_reward": 15,
                    "target_devices": ["phone", "tablet"],
                    "recurrence": {"mon": True, "tue": True, "wed": True, "thu": True, "fri": True, "sat": True, "sun": True},
                },
                {
                    "title": "Hausaufgaben",
                    "description": "Alle Hausaufgaben fertig machen",
                    "tan_reward": 20,
                    "target_devices": ["pc"],
                    "recurrence": {"mon": True, "tue": True, "wed": True, "thu": True, "fri": True},
                },
                {
                    "title": "Zaehne putzen",
                    "description": "Morgens und abends 2 Minuten",
                    "tan_reward": 5,
                    "target_devices": ["phone"],
                    "recurrence": {"mon": True, "tue": True, "wed": True, "thu": True, "fri": True, "sat": True, "sun": True},
                },
                {
                    "title": "Muell rausbringen",
                    "description": "Gelber Sack oder Restmuell",
                    "tan_reward": 10,
                    "target_devices": ["phone", "pc", "console"],
                },
            ]
            for task_data in sample_tasks:
                task = Task(
                    title=task_data["title"],
                    description=task_data.get("description"),
                    tan_reward=task_data["tan_reward"],
                    target_devices=task_data.get("target_devices"),
                    recurrence=task_data.get("recurrence"),
                    assigned_children=child_ids,
                    family_id=family.id,
                    is_active=True,
                )
                db.add(task)
                print(f"  - {task_data['title']} ({task_data['tan_reward']} Min)")

        db.commit()

        print(f"\n=== Zusammenfassung ===")
        print(f"Familie: {family_name} (ID: {family.id})")
        print(f"Invite-Code: {invite_code}")
        print(f"Eltern-Login: {parent_email} / {parent_password}")
        print(f"Kinder koennen sich mit Login-Code anmelden (ohne PIN!)")

    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed a test family with Multi-Family support")
    parser.add_argument("--family", default="Testfamilie", help="Family name")
    parser.add_argument("--parent-name", default="Eltern", help="Parent user name")
    parser.add_argument("--parent-email", default="test@zeitschatz.local", help="Parent email")
    parser.add_argument("--parent-password", default="test1234", help="Parent password")
    parser.add_argument(
        "--children",
        default="Kind:0000",
        help="Children spec: 'Name:PIN:CODE,Name2:PIN2:CODE2' (CODE optional)",
    )
    parser.add_argument("--provider-pc", default="kisi", help="Provider for PC (kisi/family_link/manual)")
    parser.add_argument("--provider-phone", default="manual", help="Provider for phone")
    parser.add_argument("--provider-tablet", default="manual", help="Provider for tablet")
    parser.add_argument("--provider-console", default="manual", help="Provider for console")
    parser.add_argument("--with-tasks", action="store_true", help="Create sample tasks")

    args = parser.parse_args()

    seed_family(
        family_name=args.family,
        parent_name=args.parent_name,
        parent_email=args.parent_email,
        parent_password=args.parent_password,
        children_spec=args.children,
        provider_pc=args.provider_pc,
        provider_phone=args.provider_phone,
        provider_tablet=args.provider_tablet,
        provider_console=args.provider_console,
        with_tasks=args.with_tasks,
    )
