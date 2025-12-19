from datetime import datetime
from pydantic import BaseModel, ConfigDict


class ORMBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Timestamped(ORMBase):
    created_at: datetime
