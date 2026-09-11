# NIRVA FastAPI Backend

This is the Phase 7A backend foundation for NIRVA. It provides a clean FastAPI boundary that will eventually host authenticated application services without changing the working Flutter application yet.

## Current architecture

```text
CURRENT: Flutter -> Supabase directly
TARGET:  Flutter -> FastAPI -> Supabase/PostgreSQL + Storage
```

The existing Supabase PostgreSQL schema and private `evidence` storage remain the source of truth. This phase does not recreate or modify that schema, initialize a database client, or migrate any Flutter service.

## Setup

From the repository root:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

The application starts without real credentials because no business or database routes are enabled yet. Configure `SUPABASE_JWT_SECRET` before enabling protected routes. Never commit `.env`, service-role keys, JWT secrets, database passwords, or access tokens.

## Environment variables

- `ENVIRONMENT`: `development`, `test`, or `production`.
- `SUPABASE_URL`: existing Supabase project URL.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only credential for future trusted operations.
- `SUPABASE_ANON_KEY`: optional server-side public key.
- `SUPABASE_JWT_SECRET`: server-only secret used by the current HS256 JWT verification abstraction.
- `SUPABASE_JWT_AUDIENCE`: expected JWT audience, normally `authenticated`.
- `DATABASE_URL`: optional future PostgreSQL connection string.
- `CORS_ORIGINS`: comma-separated development origins. Defaults to Flutter web origins on port 8080.

Secrets are typed as `SecretStr` and are never included in application responses or logs.

## Run

FastAPI uses port 8000 so it can run alongside Flutter on port 8080:

```bash
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

In Codespaces, forward port 8000 as needed. The health endpoint is available at `http://localhost:8000/health`, and interactive API documentation is available at `http://localhost:8000/docs`.

## Authentication foundation

`app.core.auth.get_current_user` extracts `Authorization: Bearer <token>` and verifies the token with PyJWT when `SUPABASE_JWT_SECRET` is configured. It requires the Supabase audience and standard subject/expiration claims. It never accepts an operator ID from request data as identity. Asymmetric Supabase signing should be implemented with JWKS verification before protected routes are enabled for such a project.
