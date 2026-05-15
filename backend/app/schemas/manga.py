from datetime import datetime
from pydantic import BaseModel


class PageOut(BaseModel):
    id: int | None = None
    index: int
    type: str = "image"
    url: str

    model_config = {"from_attributes": True}


class ChapterOut(BaseModel):
    id: int
    number: int
    title: str
    updatedAt: datetime
    pages: list[PageOut] = []

    model_config = {"from_attributes": True}


class ChapterSummary(BaseModel):
    id: int
    number: int
    title: str
    updatedAt: datetime

    model_config = {"from_attributes": True}


class MangaOut(BaseModel):
    id: int
    name: str
    coverUrl: str
    backgroundUrl: str | None
    createdAt: datetime
    updatedAt: datetime
    latestUpdatedAt: datetime | None = None
    chaptersCount: int = 0

    model_config = {"from_attributes": True}


class MangaListResponse(BaseModel):
    items: list[MangaOut]
    nextCursor: str | None = None


class MangaCreate(BaseModel):
    name: str
    coverUrl: str = ""
    backgroundUrl: str | None = None


class MangaUpdate(BaseModel):
    name: str | None = None
    coverUrl: str | None = None
    backgroundUrl: str | None = None


class PageIn(BaseModel):
    index: int
    type: str = "image"
    url: str
    id: str | None = None


class ChapterCreate(BaseModel):
    number: int
    title: str = ""
    pages: list[PageIn] = []


class ChapterUpdate(BaseModel):
    number: int | None = None
    title: str | None = None
    pages: list[PageIn] | None = None


class ChapterListResponse(BaseModel):
    items: list[ChapterSummary]
