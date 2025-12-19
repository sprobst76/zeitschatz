from pydantic import BaseModel


class LoginRequest(BaseModel):
    user_id: int
    pin: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
