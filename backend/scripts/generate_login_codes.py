#!/usr/bin/env python3
"""Generate login codes for all children who don't have one yet."""

import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models.user import User
from app.core.login_code import generate_login_code
from app.core.config import get_settings


def main():
    settings = get_settings()
    engine = create_engine(settings.database_url)
    Session = sessionmaker(bind=engine)
    db = Session()

    try:
        # Get all existing codes
        existing_codes = set(
            code for (code,) in db.query(User.login_code).filter(User.login_code.isnot(None)).all()
        )
        print(f"Found {len(existing_codes)} existing codes")

        # Find children without login codes
        children = db.query(User).filter(
            User.role == "child",
            User.login_code.is_(None)
        ).all()

        print(f"Found {len(children)} children without login codes")

        for child in children:
            # Generate unique code
            for _ in range(100):
                code = generate_login_code()
                if code not in existing_codes:
                    child.login_code = code
                    existing_codes.add(code)
                    print(f"  {child.name}: {code}")
                    break
            else:
                print(f"  {child.name}: FAILED to generate unique code!")

        db.commit()
        print(f"\nDone! Generated codes for {len(children)} children.")

    finally:
        db.close()


if __name__ == "__main__":
    main()
