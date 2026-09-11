from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import SecretStr

from app.config import Settings
from app.core.auth import get_current_user


def test_invalid_supabase_jwt_is_rejected() -> None:
    settings = Settings(
        supabase_url="https://example.supabase.co",
        supabase_jwt_secret=SecretStr("test-secret-that-is-at-least-32-bytes-long"),
    )
    credentials = HTTPAuthorizationCredentials(
        scheme="Bearer",
        credentials="not-a-jwt",
    )

    with pytest.raises(HTTPException) as error:
        get_current_user(credentials, settings)

    assert error.value.status_code == 401


def test_verified_jwt_returns_claims() -> None:
    settings = Settings(
        supabase_url="https://example.supabase.co",
        supabase_jwt_secret=SecretStr("test-secret-that-is-at-least-32-bytes-long"),
    )
    token = jwt.encode(
        {
            "sub": "user-1",
            "aud": "authenticated",
            "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
            "iss": "https://example.supabase.co/auth/v1",
        },
        "test-secret-that-is-at-least-32-bytes-long",
        algorithm="HS256",
    )

    claims = get_current_user(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials=token),
        settings,
    )

    assert claims["sub"] == "user-1"