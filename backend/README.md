# NIRVA FastAPI Backend

This is the FastAPI application boundary for NIRVA.

## Current architecture

```text
Flutter -> FastAPI -> Supabase/PostgreSQL + Storage
                         \\-> Django later: internal admin/control plane
```

The existing Supabase PostgreSQL schema and private `evidence` storage remain the source of truth. Django is a future internal admin/control-plane component and is not part of the client request path.

## Setup

From the repository root:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

The health route starts without real credentials. Case routes require `SUPABASE_URL` and the server-only `SUPABASE_SERVICE_ROLE_KEY`. JWT verification uses Supabase's public JWKS endpoint; `SUPABASE_JWT_SECRET` is not required for normal operation. Never commit `.env`, service-role keys, JWT secrets, database passwords, or access tokens.

## Environment variables

- `ENVIRONMENT`: `development`, `test`, or `production`.
- `SUPABASE_URL`: required for JWKS issuer verification and Supabase access.
- `SUPABASE_SERVICE_ROLE_KEY`: required server-only credential for trusted case database operations.
- `SUPABASE_JWT_AUDIENCE`: optional expected JWT audience; defaults to `authenticated`.
- `SUPABASE_JWT_SECRET`: optional server-only local/test fixture secret; never needed by Supabase production JWKS verification.
- `ENABLE_LOCAL_HS256_FALLBACK`: optional and defaults to `false`; keep disabled for Supabase.
- `CORS_ORIGINS`: comma-separated development origins. Defaults to Flutter web origins on port 8080.
- `CORS_ORIGIN_REGEX`: development-only regex for Codespaces forwarded HTTPS origins.

The backend automatically loads `backend/.env` using an absolute path derived from its settings module, regardless of whether Uvicorn is started from the repository root or `backend/`. Secrets are typed as `SecretStr` and are never included in application responses or logs. Flutter receives only its public Supabase configuration and the FastAPI URL through `--dart-define`.

## Run

FastAPI uses port 8000 so it can run alongside Flutter on port 8080:

```bash
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

In Codespaces, forward port 8000 as needed. The health endpoint is available at `http://localhost:8000/health`, and interactive API documentation is available at `http://localhost:8000/docs`.

## Authentication foundation

`app.core.auth.get_current_user` extracts `Authorization: Bearer <token>` and verifies Supabase ES256 tokens using the project's JWKS endpoint. It verifies the signature, issuer, audience, expiration, and subject claims. An HS256 path exists only when `ENABLE_LOCAL_HS256_FALLBACK=true` is explicitly configured for local/test fixtures. It never accepts an operator ID from request data as identity.

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

The phone must use the forwarded HTTPS URL, not `localhost`, because phone-localhost refers to the phone itself. The current Flutter app authenticates directly with Supabase for existing capture/storage flows; case and evidence analysis requests use FastAPI.

## Evidence integrity and indicative analysis

Phase 8 adds authenticated endpoints for evidence owned by the JWT subject:

- `GET /api/v1/evidence/{evidence_id}`
- `POST /api/v1/evidence/{evidence_id}/validate`
- `POST /api/v1/evidence/{evidence_id}/analyze`
- `POST /api/v1/evidence/{evidence_id}/finalize`
- `GET /api/v1/evidence/{evidence_id}/audit`
- `GET /api/v1/evidence/{evidence_id}/integrity`

Validation and analysis are generic visual demonstrations. Results such as `DEMO_CLASS_A` and `DEMO_CLASS_B` are indicative only and require laboratory confirmation. The backend stores deterministic feature metadata, a model version, confidence and uncertainty, and enforces the evidence lifecycle `CAPTURED -> VALIDATING -> ANALYZED -> FINALIZED` (or `INVALID`).

Record hashes use canonical JSON with sorted keys and compact separators, followed by `|` and the previous record hash, then SHA-256. Private signing keys are never stored in Supabase; Flutter Web exposes only a demonstration signature boundary.
