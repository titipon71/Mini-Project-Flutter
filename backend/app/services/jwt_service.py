from datetime import datetime, timedelta, timezone
import jwt

from app.config import settings


def create_access_token(uid: str, email: str | None, is_admin: bool, is_vip: bool) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": uid,
        "email": email,
        "is_admin": is_admin,
        "is_vip": is_vip,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    return jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
