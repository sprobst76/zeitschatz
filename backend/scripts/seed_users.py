"""
Seeding script to create initial parent/child users with PINs.

Usage:
  # Create default users (parent: 1234, child: 0000)
  .venv/bin/python backend/scripts/seed_users.py

  # Create custom parent
  .venv/bin/python backend/scripts/seed_users.py --parent-name "Mama" --parent-pin "5678"

  # Create custom child
  .venv/bin/python backend/scripts/seed_users.py --child-name "Max" --child-pin "1111"
"""
import argparse

from app.core.security import hash_pin
from app.db.session import SessionLocal
from app.models.user import User
from app.models.child_profile import ChildProfile


def seed(parent_name: str = "Eltern", parent_pin: str = "1234",
         child_name: str | None = "Kind", child_pin: str = "0000",
         skip_child: bool = False):
    db = SessionLocal()
    try:
        # Parent
        existing_parent = db.query(User).filter(User.role == "parent").first()
        if not existing_parent:
            parent = User(name=parent_name, role="parent", pin_hash=hash_pin(parent_pin))
            db.add(parent)
            db.flush()
            print(f"Created parent '{parent.name}' with id={parent.id}, pin={parent_pin}")
        else:
            print(f"Parent already exists: '{existing_parent.name}' id={existing_parent.id}")

        # Child (optional)
        if not skip_child:
            existing_child = db.query(User).filter(User.role == "child", User.name == child_name).first()
            if not existing_child:
                child = User(name=child_name, role="child", pin_hash=hash_pin(child_pin))
                db.add(child)
                db.flush()
                profile = ChildProfile(user_id=child.id, color="blue", icon="star")
                db.add(profile)
                print(f"Created child '{child.name}' with id={child.id}, pin={child_pin}")
            else:
                print(f"Child already exists: '{existing_child.name}' id={existing_child.id}")

        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed initial users")
    parser.add_argument("--parent-name", default="Eltern", help="Parent user name")
    parser.add_argument("--parent-pin", default="1234", help="Parent PIN (4-8 digits)")
    parser.add_argument("--child-name", default="Kind", help="Child user name")
    parser.add_argument("--child-pin", default="0000", help="Child PIN (4-8 digits)")
    parser.add_argument("--skip-child", action="store_true", help="Only create parent")
    args = parser.parse_args()

    seed(
        parent_name=args.parent_name,
        parent_pin=args.parent_pin,
        child_name=args.child_name,
        child_pin=args.child_pin,
        skip_child=args.skip_child,
    )
