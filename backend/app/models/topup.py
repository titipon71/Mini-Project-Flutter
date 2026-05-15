from datetime import datetime
from sqlalchemy import String, Text, Integer, Boolean, DateTime, DECIMAL, JSON, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base
import decimal


class Topup(Base):
    __tablename__ = "topups"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(128), ForeignKey("users.uid", ondelete="CASCADE"), nullable=False)
    user_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    package_label: Mapped[str] = mapped_column(String(100), nullable=False, default="")
    package_value: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    price_text: Mapped[str] = mapped_column(String(50), nullable=False, default="")
    amount: Mapped[decimal.Decimal] = mapped_column(DECIMAL(10, 2), nullable=False, default=0)
    amount_expected: Mapped[decimal.Decimal] = mapped_column(DECIMAL(10, 2), nullable=False, default=0)
    payment_method: Mapped[str] = mapped_column(String(50), nullable=False, default="promptpay")
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="pending")
    ref_code: Mapped[str] = mapped_column(String(100), nullable=False, default="")
    referral: Mapped[str | None] = mapped_column(String(100), nullable=True)
    slip_file_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    slip_download_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    platform: Mapped[str] = mapped_column(String(20), nullable=False, default="mobile")
    role_target: Mapped[str] = mapped_column(String(20), nullable=False, default="vip")
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    qr_amount: Mapped[decimal.Decimal | None] = mapped_column(DECIMAL(10, 2), nullable=True)
    qr_target: Mapped[str | None] = mapped_column(String(50), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    fail_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    slipok_payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    slipok_trans_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
