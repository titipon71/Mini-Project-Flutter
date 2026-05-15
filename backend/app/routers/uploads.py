import os
import uuid
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, status
from typing import Annotated
from datetime import datetime

from app.deps import get_current_user
from app.models.user import User
from app.config import settings

router = APIRouter(prefix="/api/v1/uploads", tags=["uploads"])

ALLOWED_PURPOSES = {"manga-cover", "manga-background", "chapter-page", "topup-slip", "carousel-image"}
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}


@router.post("")
async def upload_file(
    file: Annotated[UploadFile, File()],
    purpose: Annotated[str, Form()],
    current_user: Annotated[User, Depends(get_current_user)],
    manga_id: str | None = Form(default=None),
    chapter_id: str | None = Form(default=None),
    topup_id: str | None = Form(default=None),
):
    if purpose not in ALLOWED_PURPOSES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid purpose")
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid file type")

    ext = os.path.splitext(file.filename or "file.jpg")[1] or ".jpg"
    asset_id = str(uuid.uuid4())
    file_name = f"{asset_id}{ext}"

    sub_dir = os.path.join(settings.UPLOAD_DIR, purpose)
    os.makedirs(sub_dir, exist_ok=True)
    file_path = os.path.join(sub_dir, file_name)

    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    url = f"/static/{purpose}/{file_name}"
    return {
        "uploadUrl": None,
        "asset": {
            "assetId": asset_id,
            "url": url,
            "contentType": file.content_type,
            "size": len(content),
            "createdAt": datetime.utcnow().isoformat(),
        },
    }
