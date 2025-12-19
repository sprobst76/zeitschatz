from fastapi import Depends

from app.db.session import get_db


def get_db_session(db=Depends(get_db)):
    return db
