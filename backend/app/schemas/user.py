from datetime import datetime
from pydantic import BaseModel


class RolesOut(BaseModel):
    admin: bool
    vip: bool
    vipUntil: datetime | None = None


class UserProfileOut(BaseModel):
    uid: str
    email: str | None
    displayName: str | None
    photoUrl: str | None
    roles: RolesOut

    model_config = {"from_attributes": True}


class UserListResponse(BaseModel):
    items: list[UserProfileOut]
    nextCursor: str | None = None


class SetRoleRequest(BaseModel):
    role: str  # "user" | "vip" | "admin"
    durationDays: int = 30
    extend: bool = False


class SetRoleResponse(BaseModel):
    ok: bool
    uid: str
    role: str
    vipUntil: datetime | None = None
