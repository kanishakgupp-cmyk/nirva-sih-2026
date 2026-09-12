from typing import Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import InvalidTokenError, PyJWKClientError

from app.config import Settings, get_settings

_bearer_scheme = HTTPBearer(auto_error=False)


def _raise_invalid_token() -> None:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired bearer token.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Validate a Supabase JWT and return its claims.

    Live Supabase tokens are signed with asymmetric keys from JWKS. A legacy
    HS256 secret remains available as a fallback for local/test-only setups.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A bearer token is required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    issuer = (
        f"{settings.supabase_url.rstrip('/')}/auth/v1".rstrip("/")
        if settings.supabase_url
        else None
    )

    if issuer:
        try:
            jwk_client = jwt.PyJWKClient(f"{issuer}/.well-known/jwks.json")
            signing_key = jwk_client.get_signing_key_from_jwt(token)
            return jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256", "RS256"],
                audience=settings.supabase_jwt_audience,
                issuer=issuer,
                options={"require": ["sub", "aud", "exp"]},
            )
        except (InvalidTokenError, PyJWKClientError):
            if settings.supabase_jwt_secret is None:
                _raise_invalid_token()
        except Exception:
            if settings.supabase_jwt_secret is None:
                _raise_invalid_token()

    if settings.supabase_jwt_secret is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="JWT verification is not configured.",
        )

    try:
        claims = jwt.decode(
            token,
            settings.supabase_jwt_secret.get_secret_value(),
            algorithms=["HS256"],
            audience=settings.supabase_jwt_audience,
            issuer=issuer if issuer else None,
            options={"require": ["sub", "aud", "exp"]},
        )
    except InvalidTokenError:
        _raise_invalid_token()

    return claims


def get_current_user_id(
    claims: dict[str, Any] = Depends(get_current_user),
) -> str:
    """Return the verified Supabase subject used for row ownership."""
    return str(claims["sub"])
