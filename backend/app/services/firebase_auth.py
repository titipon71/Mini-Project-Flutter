import firebase_admin
from firebase_admin import auth, credentials
from app.config import settings

_initialized = False


def _init():
    global _initialized
    if not _initialized:
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        firebase_admin.initialize_app(cred)
        _initialized = True


def verify_id_token(id_token: str) -> dict:
    _init()
    return auth.verify_id_token(id_token)
