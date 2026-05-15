import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Annotated
from datetime import datetime

from app.deps import get_db, get_current_user, require_admin
from app.models.user import User
from app.models.topup import Topup
from app.schemas.topup import TopupOut, TopupListResponse, TopupCreate, TopupPatch, SlipOut

router = APIRouter(tags=["topups"])


def _to_out(t: Topup) -> TopupOut:
    slip = SlipOut(fileName=t.slip_file_name, downloadUrl=t.slip_download_url) if t.slip_file_name or t.slip_download_url else None
    return TopupOut(
        topupId=t.id, userId=t.user_id, userName=t.user_name,
        packageLabel=t.package_label, packageValue=t.package_value,
        priceText=t.price_text, amount=t.amount, amountExpected=t.amount_expected,
        paymentMethod=t.payment_method, status=t.status, refCode=t.ref_code,
        referral=t.referral, slip=slip, platform=t.platform,
        createdAt=t.created_at, updatedAt=t.updated_at,
        qrAmount=t.qr_amount, qrTarget=t.qr_target, roleTarget=t.role_target,
        durationDays=t.duration_days, expiresAt=t.expires_at, paidAt=t.paid_at,
        failReason=t.fail_reason, slipokPayload=t.slipok_payload, slipokTransRef=t.slipok_trans_ref,
    )


@router.post("/api/v1/topups", response_model=TopupOut, status_code=status.HTTP_201_CREATED)
async def create_topup(
    body: TopupCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    now = datetime.utcnow()
    topup_id = body.topupId or str(uuid.uuid4())
    topup = Topup(
        id=topup_id, user_id=current_user.uid, user_name=body.userName,
        package_label=body.packageLabel, package_value=body.packageValue,
        price_text=body.priceText, amount=body.amount, amount_expected=body.amountExpected,
        payment_method=body.paymentMethod, status="pending", ref_code=body.refCode,
        referral=body.referral, slip_download_url=body.slipUrl, platform=body.platform,
        qr_amount=body.qrAmount, qr_target=body.qrTarget, role_target=body.roleTarget,
        duration_days=body.durationDays, expires_at=body.expiresAt,
        created_at=now, updated_at=now,
    )
    db.add(topup)
    await db.commit()
    await db.refresh(topup)
    return _to_out(topup)


@router.get("/api/v1/topups/{topup_id}", response_model=TopupOut)
async def get_topup(
    topup_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    result = await db.execute(select(Topup).where(Topup.id == topup_id))
    topup = result.scalar_one_or_none()
    if not topup:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Topup not found")
    if topup.user_id != current_user.uid and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    return _to_out(topup)


@router.get("/api/v1/users/{uid}/topups", response_model=TopupListResponse)
async def list_user_topups(
    uid: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    topup_status: str | None = None,
    limit: int = 20,
    cursor: str | None = None,
):
    if uid != current_user.uid and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    q = select(Topup).where(Topup.user_id == uid).order_by(Topup.created_at.desc())
    if topup_status:
        q = q.where(Topup.status == topup_status)
    if cursor:
        q = q.where(Topup.id > cursor)
    q = q.limit(limit)
    result = await db.execute(q)
    topups = result.scalars().all()
    next_cursor = topups[-1].id if len(topups) == limit else None
    return TopupListResponse(items=[_to_out(t) for t in topups], nextCursor=next_cursor)


@router.get("/api/v1/admin/topups", response_model=TopupListResponse)
async def list_all_topups(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
    topup_status: str | None = None,
    q_search: str | None = None,
    limit: int = 50,
    cursor: str | None = None,
):
    q = select(Topup).order_by(Topup.created_at.desc())
    if topup_status:
        q = q.where(Topup.status == topup_status)
    if cursor:
        q = q.where(Topup.id > cursor)
    q = q.limit(limit)
    result = await db.execute(q)
    topups = result.scalars().all()
    next_cursor = topups[-1].id if len(topups) == limit else None
    return TopupListResponse(items=[_to_out(t) for t in topups], nextCursor=next_cursor)


@router.patch("/api/v1/admin/topups/{topup_id}", response_model=TopupOut)
async def patch_topup(
    topup_id: str,
    body: TopupPatch,
    db: Annotated[AsyncSession, Depends(get_db)],
    admin: Annotated[User, Depends(require_admin)],
):
    result = await db.execute(select(Topup).where(Topup.id == topup_id))
    topup = result.scalar_one_or_none()
    if not topup:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Topup not found")

    now = datetime.utcnow()
    topup.status = body.status
    topup.fail_reason = body.failReason
    topup.updated_at = now

    if body.status in ("approved", "paid"):
        topup.paid_at = now
        user_result = await db.execute(select(User).where(User.uid == topup.user_id))
        user = user_result.scalar_one_or_none()
        if user and topup.role_target == "vip":
            from datetime import timedelta
            user.is_vip = True
            if user.vip_until and user.vip_until > now:
                user.vip_until = user.vip_until + timedelta(days=topup.duration_days)
            else:
                user.vip_until = now + timedelta(days=topup.duration_days)
            user.updated_at = now

    await db.commit()
    await db.refresh(topup)
    return _to_out(topup)
