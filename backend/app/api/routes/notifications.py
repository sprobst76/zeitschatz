from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user
from app.services.notifications import register_token

router = APIRouter()


@router.post("/register")
def register_device(
    token: str,
    platform: str | None = None,
    user=Depends(get_current_user),
    db: Session = Depends(get_db_session),
):
    device = register_token(db, user.id, token, platform)
    return {"id": device.id, "token": device.fcm_token}
