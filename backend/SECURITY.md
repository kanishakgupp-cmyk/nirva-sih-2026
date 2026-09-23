# NIRVA Security Architecture

## Overview

The live request path is:

Flutter Web / Android -> FastAPI -> Supabase/PostgreSQL + Storage

The FastAPI boundary is the client-facing API and is responsible for enforcing identity, role checks, and the evidence workflow rules. Supabase remains the source of truth for profile, case, test-session, evidence, and audit data. Storage access is kept private and controlled by authenticated user ownership checks and server-generated access patterns.

## Authentication

The backend accepts a bearer token from the HTTP Authorization header. The token is validated against the Supabase JWKS endpoint for the configured project URL. Verification includes:

- strict verification of the selected signing key from the token `kid`
- explicit allowed algorithms: `ES256` and `RS256`
- issuer and audience validation
- expiration enforcement
- subject validation
- safe rejection for malformed or missing bearer credentials

The HS256 fallback exists only for explicit local/test fixtures and must remain disabled in production. The backend never trusts role or identity claims from a client-supplied request body.

## Authorization

Authorization is enforced server-side by the backend using the verified JWT subject and the database profile lookup for role checks.

- officer access is limited to their own cases and owned evidence
- supervisor or admin access is required for review endpoints
- finalization and review actions remain controlled by the server-side state machine and evidence-hash checks
- object access is filtered by database ownership, not by a client-supplied ID

## Evidence integrity

Evidence records use a SHA-256 hash chain:

1. canonical JSON record fields are generated in a stable, deterministic order
2. the previous record hash (if any) is appended
3. the combined value is hashed using SHA-256
4. the result is stored in `record_hash`
5. chain integrity is re-verified before supervisor review or finalization

This is a demonstration integrity mechanism, not a legal-forensics guarantee. It protects the application workflow from accidental or opportunistic tampering within the deployed system, while clearly stating that laboratory confirmation remains required.

## Data protection

- Supabase storage buckets are private by default
- user-owned storage paths are enforced by authenticated checks
- service-role credentials remain server-side only and are never shipped to the Flutter app
- database and storage policies are designed to prevent untrusted clients from directly bypassing the app boundary

## Security limits

This system provides operational integrity and controlled workflow enforcement, but it does not provide absolute tamper-proof guarantees or legal admissibility. The application intentionally keeps the evidence label as “INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED” and does not claim forensic equivalence or laboratory validation.
