"""Configuration from environment variables (12-factor). Secrets never live in code."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite:///./dev.db"
    jwt_secret: str = "dev-only-insecure-secret"
    jwt_expire_days: int = 60
    cors_origins: str = "http://localhost:5173,http://localhost:4173"
    allow_registration: bool = True
    log_level: str = "INFO"
    environment: str = "development"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
