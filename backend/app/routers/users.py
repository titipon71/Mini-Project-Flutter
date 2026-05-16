from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from typing import Annotated
from datetime import datetime, timedelta

from app.deps import get_db, get_current_user, require_admin
from app.models.user import User
from app.schemas.user import (
    UserProfileOut, RolesOut, UserListResponse, SetRoleRequest, SetRoleResponse,
    AdminUserOut, AdminUserListResponse, UpdateProfileRequest, UpdateProfileResponse,
)

router = APIRouter(tags=["users"])


def _to_profile(user: User) -> UserProfileOut:
    return UserProfileOut(
        uid=user.uid,
        email=user.email,
        displayName=user.display_name,
        photoUrl=user.photo_url,
        roles=RolesOut(admin=user.is_admin, vip=user.is_vip, vipUntil=user.vip_until),
    )


def _to_admin_user(user: User) -> AdminUserOut:
    role = "user"
    if user.is_admin:
        role = "admin"
    elif user.is_vip:
        role = "vip"
    return AdminUserOut(
        uid=user.uid,
        email=user.email,
        displayName=user.display_name,
        photoURL=user.photo_url,
        role=role,
        vipUntil=user.vip_until,
        createdAt=user.created_at,
    )


@router.get("/api/v1/me", response_model=UserProfileOut)
async def get_me(user: Annotated[User, Depends(get_current_user)]):
    return _to_profile(user)


@router.get("/api/v1/me/roles", response_model=RolesOut)
async def get_my_roles(user: Annotated[User, Depends(get_current_user)]):
    return RolesOut(admin=user.is_admin, vip=user.is_vip, vipUntil=user.vip_until)


@router.patch("/api/v1/me/profile", response_model=UpdateProfileResponse)
async def update_my_profile(
    body: UpdateProfileRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    if body.displayName is not None:
        user.display_name = body.displayName.strip() or user.display_name
    user.updated_at = datetime.utcnow()
    await db.commit()
    return UpdateProfileResponse(ok=True, displayName=user.display_name)


@router.get("/api/v1/users/{uid}", response_model=UserProfileOut)
async def get_user(uid: str, db: Annotated[AsyncSession, Depends(get_db)], _: Annotated[User, Depends(require_admin)]):
    result = await db.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _to_profile(user)


@router.get("/api/v1/admin/users", response_model=AdminUserListResponse)
async def list_users(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
    search: str | None = None,
    limit: int = 500,
):
    q = select(User).order_by(User.created_at.desc())
    if search:
        q = q.where(or_(User.email.ilike(f"%{search}%"), User.display_name.ilike(f"%{search}%")))
    q = q.limit(limit)
    result = await db.execute(q)
    users = result.scalars().all()
    return AdminUserListResponse(users=[_to_admin_user(u) for u in users])


@router.patch("/api/v1/admin/users/{uid}/roles", response_model=SetRoleResponse)
async def set_user_role(
    uid: str,
    body: SetRoleRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    result = await db.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    now = datetime.utcnow()
    vip_until: datetime | None = None

    if body.role == "admin":
        user.is_admin = True
        user.is_vip = False
        user.vip_until = None
    elif body.role == "vip":
        user.is_admin = False
        user.is_vip = True
        if body.extend and user.vip_until and user.vip_until > now:
            vip_until = user.vip_until + timedelta(days=body.durationDays)
        else:
            vip_until = now + timedelta(days=body.durationDays)
        user.vip_until = vip_until
    else:
        user.is_admin = False
        user.is_vip = False
        user.vip_until = None

    user.updated_at = now
    await db.commit()
    return SetRoleResponse(ok=True, uid=uid, role=body.role, vipUntil=user.vip_until)
