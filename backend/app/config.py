from functools import lru_cache
from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[1] / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: str = "development"
    supabase_url: str = ""
    supabase_service_role_key: SecretStr | None = None
    supabase_anon_key: SecretStr | None = None
    supabase_jwt_secret: SecretStr | None = None
    supabase_jwt_audience: str = "authenticated"
    enable_local_hs256_fallback: bool = False
    database_url: SecretStr | None = None
    cors_origins: str = (
        "http://localhost:8080,http://127.0.0.1:8080,"
        "http://localhost:8000,http://127.0.0.1:8000"
    )
    cors_origin_regex: str = (
        r"^https://[a-z0-9-]+-8081\.(app\.github\.dev|githubpreview\.dev)$"
    )

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
