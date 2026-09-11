from functools import lru_cache

from fastapi import HTTPException, status
from supabase import Client, create_client

from app.config import get_settings


@lru_cache
def get_supabase_client() -> Client:
    settings = get_settings()
    if not settings.supabase_url or settings.supabase_service_role_key is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase server configuration is not available.",
        )
    return create_client(
        settings.supabase_url,
        settings.supabase_service_role_key.get_secret_value(),
    )


def get_configured_supabase_client() -> Client:
    return get_supabase_client()