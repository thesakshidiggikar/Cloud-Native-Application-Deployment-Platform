from functools import lru_cache

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings; environment variables override the local .env file."""

    model_config = SettingsConfigDict(
        env_prefix="APP_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    name: str = "Devopshere API"
    version: str = "0.1.0"
    environment: str = "local"
    log_level: str = "INFO"
    database_url: SecretStr | None = None
    redis_url: SecretStr | None = None
    cache_ttl_seconds: int = Field(default=30, ge=1, le=3600)


@lru_cache
def get_settings() -> Settings:
    return Settings()
