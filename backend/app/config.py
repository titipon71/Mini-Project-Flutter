from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    DATABASE_URL: str = "mysql+aiomysql://root:password@localhost:3306/twebtoon"
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"
    SLIPOK_API_KEY: str = ""
    SLIPOK_ENDPOINT: str = "https://api.slipok.com/api/line/apikey/54127"
    UPLOAD_DIR: str = "./uploads"
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]


settings = Settings()
