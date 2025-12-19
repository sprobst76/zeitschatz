from datetime import datetime
from app.schemas.common import ORMBase


class UserRead(ORMBase):
    id: int
    name: str
    role: str
    is_active: bool
    created_at: datetime
