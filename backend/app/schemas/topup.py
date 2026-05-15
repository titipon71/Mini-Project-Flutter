from datetime import datetime
from pydantic import BaseModel
from decimal import Decimal


class SlipOut(BaseModel):
    fileName: str | None = None
    downloadUrl: str | None = None


class TopupOut(BaseModel):
    topupId: str
    userId: str
    userName: str | None
    packageLabel: str
    packageValue: int
    priceText: str
    amount: Decimal
    amountExpected: Decimal
    paymentMethod: str
    status: str
    refCode: str
    referral: str | None
    slip: SlipOut | None = None
    platform: str
    createdAt: datetime
    updatedAt: datetime
    qrAmount: Decimal | None = None
    qrTarget: str | None = None
    roleTarget: str
    durationDays: int
    expiresAt: datetime | None = None
    paidAt: datetime | None = None
    failReason: str | None = None
    slipokPayload: dict | None = None
    slipokTransRef: str | None = None

    model_config = {"from_attributes": True}


class TopupListResponse(BaseModel):
    items: list[TopupOut]
    nextCursor: str | None = None


class TopupCreate(BaseModel):
    topupId: str | None = None
    userId: str
    userName: str | None = None
    packageLabel: str
    packageValue: int
    priceText: str
    amount: Decimal
    amountExpected: Decimal
    paymentMethod: str = "promptpay"
    refCode: str
    referral: str | None = None
    slipUrl: str | None = None
    platform: str = "mobile"
    qrAmount: Decimal | None = None
    qrTarget: str | None = None
    roleTarget: str = "vip"
    durationDays: int = 30
    expiresAt: datetime | None = None


class TopupPatch(BaseModel):
    status: str
    failReason: str | None = None
