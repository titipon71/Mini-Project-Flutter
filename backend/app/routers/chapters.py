from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import Annotated
from datetime import datetime

from app.deps import get_db, require_admin
from app.models.user import User
from app.models.manga import Manga, Chapter, Page
from app.schemas.manga import ChapterOut, ChapterListResponse, ChapterCreate, ChapterUpdate, PageOut

router = APIRouter(prefix="/api/v1/mangas/{manga_id}/chapters", tags=["chapters"])


def _to_chapter_out(chapter: Chapter) -> ChapterOut:
    pages = [PageOut(id=p.id, index=p.page_index, type=p.type, url=p.url) for p in chapter.pages]
    return ChapterOut(id=chapter.id, number=chapter.number, title=chapter.title, updatedAt=chapter.updated_at, pages=pages)


async def _get_manga_or_404(manga_id: int, db: AsyncSession) -> Manga:
    result = await db.execute(select(Manga).where(Manga.id == manga_id))
    manga = result.scalar_one_or_none()
    if not manga:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Manga not found")
    return manga


@router.get("", response_model=ChapterListResponse)
async def list_chapters(manga_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    await _get_manga_or_404(manga_id, db)
    result = await db.execute(select(Chapter).where(Chapter.manga_id == manga_id).order_by(Chapter.number))
    chapters = result.scalars().all()
    from app.schemas.manga import ChapterSummary
    items = [ChapterSummary(id=c.id, number=c.number, title=c.title, updatedAt=c.updated_at) for c in chapters]
    return ChapterListResponse(items=items)


@router.get("/{chapter_id}", response_model=ChapterOut)
async def get_chapter(manga_id: int, chapter_id: int, db: Annotated[AsyncSession, Depends(get_db)]):
    result = await db.execute(
        select(Chapter).options(selectinload(Chapter.pages)).where(Chapter.id == chapter_id, Chapter.manga_id == manga_id)
    )
    chapter = result.scalar_one_or_none()
    if not chapter:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chapter not found")
    return _to_chapter_out(chapter)


@router.post("", response_model=ChapterOut, status_code=status.HTTP_201_CREATED)
async def create_chapter(
    manga_id: int,
    body: ChapterCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    await _get_manga_or_404(manga_id, db)
    now = datetime.utcnow()
    chapter = Chapter(manga_id=manga_id, number=body.number, title=body.title, updated_at=now)
    db.add(chapter)
    await db.flush()
    for p in body.pages:
        db.add(Page(chapter_id=chapter.id, page_index=p.index, type=p.type, url=p.url))
    await db.commit()
    result = await db.execute(select(Chapter).options(selectinload(Chapter.pages)).where(Chapter.id == chapter.id))
    chapter = result.scalar_one()
    return _to_chapter_out(chapter)


@router.put("/{chapter_id}", response_model=ChapterOut)
async def update_chapter(
    manga_id: int,
    chapter_id: int,
    body: ChapterUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    result = await db.execute(
        select(Chapter).options(selectinload(Chapter.pages)).where(Chapter.id == chapter_id, Chapter.manga_id == manga_id)
    )
    chapter = result.scalar_one_or_none()
    if not chapter:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chapter not found")
    if body.number is not None:
        chapter.number = body.number
    if body.title is not None:
        chapter.title = body.title
    if body.pages is not None:
        for page in chapter.pages:
            await db.delete(page)
        for p in body.pages:
            db.add(Page(chapter_id=chapter.id, page_index=p.index, type=p.type, url=p.url))
    chapter.updated_at = datetime.utcnow()
    await db.commit()
    result = await db.execute(select(Chapter).options(selectinload(Chapter.pages)).where(Chapter.id == chapter.id))
    chapter = result.scalar_one()
    return _to_chapter_out(chapter)


@router.delete("/{chapter_id}")
async def delete_chapter(
    manga_id: int,
    chapter_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
):
    result = await db.execute(select(Chapter).where(Chapter.id == chapter_id, Chapter.manga_id == manga_id))
    chapter = result.scalar_one_or_none()
    if not chapter:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chapter not found")
    await db.delete(chapter)
    await db.commit()
    return {"ok": True}
