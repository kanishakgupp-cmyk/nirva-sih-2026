from typing import Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import InvalidTokenError

from app.config import Settings, get_settings

_bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Validate a Supabase JWT and return its claims.

    Supabase projects using the legacy JWT secret can be validated locally with
    this HS256 verifier. Projects using asymmetric signing should replace this
    implementation with JWKS-based verification before enabling protected routes.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A bearer token is required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if settings.supabase_jwt_secret is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="JWT verification is not configured.",
        )

    issuer = f"{settings.supabase_url.rstrip('/')}/auth/v1".rstrip("/")
    try:
        claims = jwt.decode(
            credentials.credentials,
            settings.supabase_jwt_secret.get_secret_value(),
            algorithms=["HS256"],
            audience=settings.supabase_jwt_audience,
            issuer=issuer if settings.supabase_url else None,
            options={"require": ["sub", "aud", "exp"]},
        )
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    return claims
