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


# Flat format expected by Flutter admin screens
class AdminUserOut(BaseModel):
    uid: str
    email: str | None
    displayName: str | None
    photoURL: str | None
    role: str  # "user" | "vip" | "admin"
    vipUntil: datetime | None = None
    createdAt: datetime | None = None


class AdminUserListResponse(BaseModel):
    users: list[AdminUserOut]


class UpdateProfileRequest(BaseModel):
    displayName: str | None = None


class UpdateProfileResponse(BaseModel):
    ok: bool
    displayName: str | None
