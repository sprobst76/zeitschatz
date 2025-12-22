from functools import lru_cache
from typing import Any
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

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
    cors_origins: str = Field(default="*", alias="CORS_ORIGINS")
    dev_bypass_auth: bool = Field(default=False, alias="DEV_BYPASS_AUTH")
    dev_user_id: int = Field(default=1, alias="DEV_USER_ID")
    dev_user_role: str = Field(default="parent", alias="DEV_USER_ROLE")

    # Email settings
    smtp_host: str = Field(default="", alias="SMTP_HOST")
    smtp_port: int = Field(default=587, alias="SMTP_PORT")
    smtp_user: str = Field(default="", alias="SMTP_USER")
    smtp_password: str = Field(default="", alias="SMTP_PASSWORD")
    smtp_from: str = Field(default="ZeitSchatz <noreply@zeitschatz.de>", alias="SMTP_FROM")
    smtp_tls: bool = Field(default=True, alias="SMTP_TLS")

    # App URLs
    app_url: str = Field(default="http://localhost:8070", alias="APP_URL")
    frontend_url: str = Field(default="http://localhost:8081", alias="FRONTEND_URL")

    # Family settings
    invite_code_expiry_days: int = Field(default=7, alias="INVITE_CODE_EXPIRY_DAYS")

    def get_cors_origins(self) -> list[str]:
        """Parse CORS origins from comma-separated string."""
        if not self.cors_origins or self.cors_origins == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
