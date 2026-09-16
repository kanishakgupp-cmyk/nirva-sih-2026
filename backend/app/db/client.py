from functools import lru_cache

import httpx
from fastapi import HTTPException, status
from supabase import Client, ClientOptions, create_client

from app.config import get_settings


@lru_cache
def get_supabase_client() -> Client:
    settings = get_settings()

    if not settings.supabase_url or settings.supabase_service_role_key is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase server configuration is not available.",
        )

    http_client = httpx.Client(
        http2=False,
        timeout=httpx.Timeout(
            connect=10.0,
            read=30.0,
            write=30.0,
            pool=30.0,
        ),
        limits=httpx.Limits(
            max_connections=20,
            max_keepalive_connections=10,
        ),
    )

    options = ClientOptions(
        httpx_client=http_client,
    )

    return create_client(
        settings.supabase_url,
        settings.supabase_service_role_key.get_secret_value(),
        options=options,
    )


def get_configured_supabase_client() -> Client:
    return get_supabase_client()
