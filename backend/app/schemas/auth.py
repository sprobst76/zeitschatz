from pydantic import BaseModel


class LoginRequest(BaseModel):
    user_id: int
    pin: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
