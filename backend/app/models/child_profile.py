from sqlalchemy import Column, ForeignKey, Integer, String

from app.models.base import Base


class ChildProfile(Base):
    __tablename__ = "children_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    color = Column(String(20), nullable=True)
    icon = Column(String(50), nullable=True)
