import json
from typing import List

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models.device import DeviceToken

settings = get_settings()


def register_token(db: Session, user_id: int, token: str, platform: str | None = None) -> DeviceToken:
    existing = db.query(DeviceToken).filter(DeviceToken.fcm_token == token).first()
    if existing:
        return existing
    device = DeviceToken(user_id=user_id, fcm_token=token, platform=platform)
    db.add(device)
    db.commit()
    db.refresh(device)
    return device


async def send_push(tokens: List[str], payload: dict) -> None:
    if not settings.fcm_server_key:
        print("[push] FCM_SERVER_KEY not set, skipping push")
        return
    if not tokens:
        return

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"key={settings.fcm_server_key}",
    }
    body = {"registration_ids": tokens, "data": payload}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post("https://fcm.googleapis.com/fcm/send", headers=headers, content=json.dumps(body))
            print(f"[push] status={resp.status_code} body={resp.text[:200]}")
    except Exception as exc:
        print(f"[push] error sending push: {exc}")
