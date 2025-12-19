from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "ZeitSchatz"
    env: str = Field(default="local", alias="ENV")
    secret_key: str = Field(default="changeme", alias="SECRET_KEY")
    access_token_expire_minutes: int = Field(default=60, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    refresh_token_expire_days: int = Field(default=7, alias="REFRESH_TOKEN_EXPIRE_DAYS")
    database_url: str = Field(default="sqlite:///./data/zeit.db", alias="DATABASE_URL")
    storage_dir: str = Field(default="/data/photos", alias="STORAGE_DIR")
    photo_retention_days: int = Field(default=14, alias="PHOTO_RETENTION_DAYS")
    fcm_server_key: str = Field(default="", alias="FCM_SERVER_KEY")
    tan_default_duration_minutes: int = Field(default=30, alias="TAN_DEFAULT_DURATION_MINUTES")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
