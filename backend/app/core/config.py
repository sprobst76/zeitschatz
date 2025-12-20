from functools import lru_cache
from pydantic import Field, field_validator
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
    photo_max_bytes: int = Field(default=5_000_000, alias="PHOTO_MAX_BYTES")
    cors_origins: list[str] = Field(default_factory=lambda: ["*"], alias="CORS_ORIGINS")
    dev_bypass_auth: bool = Field(default=False, alias="DEV_BYPASS_AUTH")
    dev_user_id: int = Field(default=1, alias="DEV_USER_ID")
    dev_user_role: str = Field(default="parent", alias="DEV_USER_ROLE")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False
        extra = "ignore"

    @field_validator("cors_origins", mode="before")
    @classmethod
    def split_cors_origins(cls, value):
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return ["*"]
            if stripped.startswith("["):
                return value
            return [item.strip() for item in stripped.split(",") if item.strip()]
        return value


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
