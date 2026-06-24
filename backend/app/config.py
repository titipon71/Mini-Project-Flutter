from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    DATABASE_URL: str = "mysql+aiomysql://root:password@localhost:3306/twebtoon"
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"
    SLIPOK_API_KEY: str = ""
    SLIPOK_ENDPOINT: str = "https://api.slipok.com/api/line/apikey/54127"
    UPLOAD_DIR: str = "./uploads"

    JWT_SECRET_KEY: str = "change-this-to-a-strong-random-secret-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:7357",
        "http://localhost:8080",
        "http://localhost:8081",
        "http://localhost:52200",
        "http://127.0.0.1",
        "http://127.0.0.1:8080",
    ]


settings = Settings()
