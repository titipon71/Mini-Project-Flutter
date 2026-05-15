from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from typing import Annotated
from datetime import datetime

from app.deps import get_db, require_admin
from app.models.user import User
from app.models.manga import Manga, Chapter
from app.schemas.manga import MangaOut, MangaListResponse, MangaCreate, MangaUpdate

router = APIRouter(prefix="/api/v1/mangas", tags=["mangas"])


def _to_manga_out(manga: Manga, chapters: list[Chapter] | None = None) -> MangaOut:
    chapter_list = chapters if chapters is not None else manga.chapters
    chapters_count = len(chapter_list)
    latest = max((c.updated_at for c in chapter_list), default=None) if chapter_list else None
    return MangaOut(
        id=manga.id,
        name=manga.name,
        coverUrl=manga.cover_url,
        backgroundUrl=manga.background_url,
        createdAt=manga.created_at,
        updatedAt=manga.updated_at,
        latestUpdatedAt=latest,
        chaptersCount=chapters_count,
    )


@router.get("", response_model=MangaListResponse)
async def list_mangas(db: Annotated[AsyncSession, Depends(get_db)], limit: int = 50, cursor: int | None = None):
    q = select(Manga).options(selectinload(Manga.chapters)).order_by(Manga.id)
    if cursor:
        q = q.where(Manga.id > cursor)
    q = q.limit(limit)
    result = await db.execute(q)
    mangas = result.scalars().all()
    items = [_to_manga_out(m) for m in mangas]
    next_cursor = str(mangas[-1].id) if len(mangas) == limit else None
    return MangaListResponse(items=items, nextCursor=next_cursor)


@router.get("/{manga_id}", response_model=MangaOut)
async def get_manga(manga_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(select(Manga).options(selectinload(Manga.chapters)).where(Manga.id == manga_id))
    manga = result.scalar_one_or_none()
    if not manga:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Manga not found")
    return _to_manga_out(manga)


@router.post("", response_model=MangaOut, status_code=status.HTTP_201_CREATED)
async def create_manga(
    body: MangaCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    now = datetime.utcnow()
    manga = Manga(name=body.name, cover_url=body.coverUrl, background_url=body.backgroundUrl, created_at=now, updated_at=now)
    db.add(manga)
    await db.commit()
    await db.refresh(manga)
    return _to_manga_out(manga, [])


@router.put("/{manga_id}", response_model=MangaOut)
async def update_manga(
    manga_id: int,
    body: MangaUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    result = await db.execute(select(Manga).options(selectinload(Manga.chapters)).where(Manga.id == manga_id))
    manga = result.scalar_one_or_none()
    if not manga:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Manga not found")
    if body.name is not None:
        manga.name = body.name
    if body.coverUrl is not None:
        manga.cover_url = body.coverUrl
    if body.backgroundUrl is not None:
        manga.background_url = body.backgroundUrl
    manga.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(manga)
    return _to_manga_out(manga)


@router.delete("/{manga_id}")
async def delete_manga(
    manga_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    result = await db.execute(select(Manga).where(Manga.id == manga_id))
    manga = result.scalar_one_or_none()
    if not manga:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Manga not found")
    await db.delete(manga)
    await db.commit()
    return {"ok": True}
