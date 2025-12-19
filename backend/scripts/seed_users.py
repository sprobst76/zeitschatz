"""
Simple seeding script to create initial parent/child users with PINs.
Usage:
  .venv/bin/python backend/scripts/seed_users.py
"""
from app.core.security import hash_pin
from app.db.session import SessionLocal
from app.models.user import User
from app.models.child_profile import ChildProfile


def seed():
    db = SessionLocal()
    try:
        # Parent
        if not db.query(User).filter(User.role == "parent").first():
            parent = User(name="Eltern", role="parent", pin_hash=hash_pin("1234"))
            db.add(parent)
            db.flush()
            print(f"Created parent with id={parent.id}, pin=1234")
        else:
            parent = db.query(User).filter(User.role == "parent").first()
            print(f"Parent already exists id={parent.id}")

        # Child
        child = db.query(User).filter(User.role == "child").first()
        if not child:
            child = User(name="Kind", role="child", pin_hash=hash_pin("0000"))
            db.add(child)
            db.flush()
            profile = ChildProfile(user_id=child.id, color="blue", icon="star")
            db.add(profile)
            print(f"Created child with id={child.id}, pin=0000")
        else:
            print(f"Child already exists id={child.id}")

        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    seed()
