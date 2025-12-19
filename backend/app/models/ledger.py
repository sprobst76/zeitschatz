from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

from app.models.base import Base


class TanLedger(Base):
    __tablename__ = "tan_ledger"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    submission_id = Column(Integer, ForeignKey("submissions.id", ondelete="SET NULL"), nullable=True)
    minutes = Column(Integer, nullable=False)  # Dauer der Freigabe
    target_device = Column(String(50), nullable=True)  # device binding
    tan_code = Column(String(12), nullable=True)  # 6-8 stelliger Code aus Kisi-Bestand
    valid_until = Column(DateTime, nullable=True)  # optionaler Ablaufzeitpunkt
    reason = Column(String(255), nullable=True)
    paid_out = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
