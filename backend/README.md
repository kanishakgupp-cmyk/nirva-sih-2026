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

The health route starts without real credentials. Case routes require both JWT verification and the server-side Supabase configuration. Never commit `.env`, service-role keys, JWT secrets, database passwords, or access tokens.

## Environment variables

- `ENVIRONMENT`: `development`, `test`, or `production`.
- `SUPABASE_URL`: existing Supabase project URL.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only credential for future trusted operations.
- `SUPABASE_ANON_KEY`: optional server-side public key.
- `SUPABASE_JWT_SECRET`: server-only secret used by the current HS256 JWT verification abstraction.
- `SUPABASE_JWT_AUDIENCE`: expected JWT audience, normally `authenticated`.
- `DATABASE_URL`: optional future PostgreSQL connection string.
- `CORS_ORIGINS`: comma-separated development origins. Defaults to Flutter web origins on port 8080.
- `CORS_ORIGIN_REGEX`: development-only regex for Codespaces forwarded HTTPS origins.

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

## Case API

The first migrated resource is case management:

- `GET /api/v1/cases`
- `POST /api/v1/cases`
- `GET /api/v1/cases/{case_id}`

All case routes require a verified Supabase bearer token. Case ownership is derived from the JWT `sub` claim; request bodies cannot choose `created_by`. The server uses the existing Supabase project and `SUPABASE_SERVICE_ROLE_KEY` only on the backend. The service applies the authenticated user filter explicitly because service-role access bypasses Supabase RLS.

For Codespaces, start the server on port 8000 and forward that port from the Ports panel. Use the generated HTTPS URL as Flutter's runtime API base URL:

```bash
flutter run -d chrome \
	--dart-define=SUPABASE_URL=https://your-project.supabase.co \
	--dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
	--dart-define=API_BASE_URL=https://your-forwarded-8000-url
```

The phone must use the forwarded HTTPS URL, not `localhost`, because phone-localhost refers to the phone itself. The current Flutter app still authenticates directly with Supabase; only case data requests use FastAPI.
