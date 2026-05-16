from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Annotated

from app.deps import get_db
from app.models.user import User
from app.services.firebase_auth import verify_id_token
from app.services.jwt_service import create_access_token
from app.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


class TokenRequest(BaseModel):
    firebase_token: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


@router.post("/token", response_model=TokenResponse)
async def exchange_token(
    body: TokenRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Exchange a Firebase ID token for a local JWT."""
    try:
        decoded = verify_id_token(body.firebase_token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Firebase token")

    uid = decoded["uid"]
    result = await db.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            uid=uid,
            email=decoded.get("email"),
            display_name=decoded.get("name"),
            photo_url=decoded.get("picture"),
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    token = create_access_token(
        uid=user.uid,
        email=user.email,
        is_admin=user.is_admin,
        is_vip=user.is_vip,
    )
    return TokenResponse(
        access_token=token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )
