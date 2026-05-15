from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from typing import Annotated

from app.deps import get_db, require_admin
from app.models.user import User
from app.models.website import CarouselImage
from app.schemas.website import WebsiteInfoOut, WebsiteInfoUpdate

router = APIRouter(prefix="/api/v1/website-info", tags=["website-info"])


@router.get("", response_model=WebsiteInfoOut)
async def get_website_info(db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(CarouselImage).order_by(CarouselImage.sort_order))
    images = result.scalars().all()
    return WebsiteInfoOut(carouselImages=[img.url for img in images])


@router.put("", response_model=WebsiteInfoOut)
async def update_website_info(
    body: WebsiteInfoUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    await db.execute(delete(CarouselImage))
    for i, url in enumerate(body.carouselImages):
        db.add(CarouselImage(url=url, sort_order=i))
    await db.commit()
    return WebsiteInfoOut(carouselImages=body.carouselImages)
