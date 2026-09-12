import base64
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.config import Settings
from app.core.auth import get_current_user
from app.main import app


def test_invalid_supabase_jwt_is_rejected() -> None:
    settings = Settings(
        supabase_url="https://example.supabase.co",
        supabase_jwt_secret=SecretStr("test-secret-that-is-at-least-32-bytes-long"),
        enable_local_hs256_fallback=True,
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
        enable_local_hs256_fallback=True,
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


def test_verified_jwt_returns_claims_with_jwks(monkeypatch) -> None:
    settings = Settings(
        supabase_url="https://example.supabase.co",
        supabase_jwt_secret=None,
    )

    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()
    public_numbers = public_key.public_numbers()

    def b64url(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

    jwk = {
        "kty": "EC",
        "kid": "test-key",
        "use": "sig",
        "alg": "ES256",
        "crv": "P-256",
        "x": b64url(public_numbers.x.to_bytes(32, byteorder="big")),
        "y": b64url(public_numbers.y.to_bytes(32, byteorder="big")),
    }

    token = jwt.encode(
        {
            "sub": "user-2",
            "aud": "authenticated",
            "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
            "iss": "https://example.supabase.co/auth/v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": jwk["kid"]},
    )

    class FakeJWKClient:
        def __init__(self, url: str):
            assert url == "https://example.supabase.co/auth/v1/.well-known/jwks.json"

        def get_signing_key_from_jwt(self, jwt_token: str):
            assert jwt_token == token
            return type("SigningKey", (), {"key": public_key})()

    monkeypatch.setattr(jwt, "PyJWKClient", FakeJWKClient)

    claims = get_current_user(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials=token),
        settings,
    )

    assert claims["sub"] == "user-2"


@pytest.mark.parametrize(
    ("claim", "value"),
    [
        ("iss", "https://wrong.supabase.co/auth/v1"),
        ("aud", "wrong-audience"),
        ("exp", datetime.now(timezone.utc) - timedelta(minutes=5)),
    ],
)
def test_jwks_rejects_invalid_registered_claims(monkeypatch, claim, value) -> None:
    settings = Settings(supabase_url="https://example.supabase.co")
    private_key = ec.generate_private_key(ec.SECP256R1())
    token = jwt.encode(
        {
            "sub": "user-3",
            "aud": "authenticated",
            "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
            "iss": "https://example.supabase.co/auth/v1",
            claim: value,
        },
        private_key,
        algorithm="ES256",
        headers={"kid": "test-key"},
    )

    class FakeJWKClient:
        def __init__(self, url: str):
            pass

        def get_signing_key_from_jwt(self, jwt_token: str):
            return type("SigningKey", (), {"key": private_key.public_key()})()

    monkeypatch.setattr(jwt, "PyJWKClient", FakeJWKClient)

    with pytest.raises(HTTPException) as error:
        get_current_user(
            HTTPAuthorizationCredentials(scheme="Bearer", credentials=token),
            settings,
        )

    assert error.value.status_code == 401


def test_jwks_requires_subject(monkeypatch) -> None:
    settings = Settings(supabase_url="https://example.supabase.co")
    private_key = ec.generate_private_key(ec.SECP256R1())
    token = jwt.encode(
        {
            "aud": "authenticated",
            "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
            "iss": "https://example.supabase.co/auth/v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": "test-key"},
    )

    class FakeJWKClient:
        def __init__(self, url: str):
            pass

        def get_signing_key_from_jwt(self, jwt_token: str):
            return type("SigningKey", (), {"key": private_key.public_key()})()

    monkeypatch.setattr(jwt, "PyJWKClient", FakeJWKClient)

    with pytest.raises(HTTPException) as error:
        get_current_user(
            HTTPAuthorizationCredentials(scheme="Bearer", credentials=token),
            settings,
        )

    assert error.value.status_code == 401


def test_codespaces_flutter_origin_is_allowed() -> None:
    client = TestClient(app)
    origin = "https://automatic-space-trout-vpp66ww7rxgx2x4vj-8080.app.github.dev"

    response = client.options(
        "/api/v1/cases",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin