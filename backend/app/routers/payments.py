from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Annotated
from datetime import datetime, timedelta

from app.deps import get_db, get_current_user, require_admin
from app.models.user import User
from app.models.topup import Topup
from app.services.slipok import verify_slip_by_url

router = APIRouter(prefix="/api/v1/payments", tags=["payments"])


@router.post("/slipok/verify")
async def slipok_verify(
    body: dict,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(get_current_user)],
):
    url = body.get("url", "")
    amount = body.get("amount", 0)
    if not url:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="url required")
    data = await verify_slip_by_url(url, amount)
    return {"ok": True, "slipok": data}


@router.post("/slipok/webhook")
async def slipok_webhook(request: Request, db: Annotated[AsyncSession, Depends(get_db)]):
    payload = await request.json()
    trans_ref = payload.get("transRef") or payload.get("data", {}).get("transRef")
    if not trans_ref:
        return {"ok": False, "reason": "no transRef"}

    result = await db.execute(select(Topup).where(Topup.ref_code == trans_ref))
    topup = result.scalar_one_or_none()
    if not topup:
        return {"ok": False, "reason": "topup not found"}

    now = datetime.utcnow()
    topup.status = "approved"
    topup.paid_at = now
    topup.slipok_payload = payload
    topup.slipok_trans_ref = trans_ref
    topup.updated_at = now

    user_result = await db.execute(select(User).where(User.uid == topup.user_id))
    user = user_result.scalar_one_or_none()
    if user and topup.role_target == "vip":
        user.is_vip = True
        if user.vip_until and user.vip_until > now:
            user.vip_until = user.vip_until + timedelta(days=topup.duration_days)
        else:
            user.vip_until = now + timedelta(days=topup.duration_days)
        user.updated_at = now

    await db.commit()
    return {"ok": True}


@router.post("/topups/{topup_id}/manual-verify")
async def manual_verify(
    topup_id: str,
    body: dict,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    result = await db.execute(select(Topup).where(Topup.id == topup_id))
    topup = result.scalar_one_or_none()
    if not topup:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Topup not found")

    slip_url = body.get("slipUrl") or topup.slip_download_url
    if not slip_url:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="slipUrl required")

    now = datetime.utcnow()
    topup.status = "under_review"
    topup.updated_at = now
    await db.commit()

    try:
        data = await verify_slip_by_url(slip_url, float(topup.amount_expected))
        topup.slipok_payload = data
        topup.status = "approved"
        topup.paid_at = now
        topup.updated_at = now

        user_result = await db.execute(select(User).where(User.uid == topup.user_id))
        user = user_result.scalar_one_or_none()
        if user and topup.role_target == "vip":
            user.is_vip = True
            if user.vip_until and user.vip_until > now:
                user.vip_until = user.vip_until + timedelta(days=topup.duration_days)
            else:
                user.vip_until = now + timedelta(days=topup.duration_days)
            user.updated_at = now

        await db.commit()
        return {"ok": True, "verified": True}
    except Exception as e:
        topup.status = "rejected"
        topup.fail_reason = str(e)
        topup.updated_at = now
        await db.commit()
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
