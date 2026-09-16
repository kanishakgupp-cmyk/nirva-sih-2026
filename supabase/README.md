# NIRVA Supabase configuration

NIRVA uses Supabase as the online source of truth. The Flutter application receives its connection values at runtime through `--dart-define`.

## Project URL

The Supabase project URL is available in the Supabase Dashboard under **Project Settings > Data API** (also shown as the project URL in the API settings). The current project URL is:

```text
https://mueuxechryopwszijgrn.supabase.co
```

The URL is not a secret, but it should still be supplied through the existing `SUPABASE_URL` dart-define when running the Flutter application.

## Publishable key

The publishable client key is available in the Supabase Dashboard under **Project Settings > API**, in the publishable keys section. Supply it to Flutter without writing it into the repository:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://mueuxechryopwszijgrn.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Never commit the publishable key or place it in Dart source, checked-in configuration, logs, screenshots, or documentation. Do not use a service-role key in Flutter.

Service-role keys, database passwords, and other server credentials must remain server-side and must never be placed in the Flutter application or committed to this repository.

## Applying the migration

The migration at `supabase/migrations/001_initial_schema.sql` is intended to be applied by an authorized project administrator through a trusted server-side workflow. Suitable options include:

- The Supabase Dashboard SQL Editor, after reviewing the complete migration.
- The Supabase CLI linked to the intended project, using an authenticated administrator workflow.

Do not run this migration from Flutter. The migration creates the initial tables, indexes, Row Level Security policies, and one safe demo kit. Applying it remotely requires access to the Supabase project and appropriate administrative credentials; those credentials must not be stored in this repository or shipped to clients.

After applying it, verify the tables and policies in the Supabase Dashboard. The Flutter client is intentionally limited to the policies defined in the migration and cannot modify kit records.

## Phase 9 supervisor migrations and verified live status

Supervisor review (Phase 9) requires two forward-only migrations, applied in order by an authorized project administrator:

1. `migrations/006_supervisor_review.sql` — adds `review_status`, `review_reason`, `reviewed_by`, `reviewed_at`, the review-status check constraint, and a review index.
2. `migrations/007_supervisor_hardening.sql` — drops `NOT NULL` from `test_sessions.kit_id` (a kit is attached after verification), allows the explicit `EXPIRED` kit status, stops `anon`/`authenticated` writes to the supervisor review fields, makes `FINALIZED` evidence rows immutable except for review metadata, and requires a review reason for `FLAGGED`/`RETURNED`.

Applying `007` is safe for existing prototype data: the review-reason check is added as `NOT VALID`, so pre-existing rows are left untouched while every new write is enforced.

Live schema inspection of the current project (read-only, service-role) shows:

- migrations `001`–`005` are applied (`evidence_status`, indicative analysis columns, hash-chain and signature metadata exist);
- migration `006` is **not applied yet**: `evidence_records.review_status` does not exist. Until it is applied the supervisor endpoints answer `HTTP 503` with the migration name to run, instead of a generic server error;
- the private `evidence` storage bucket exists and is not public;
- no `SUPERVISOR`/`ADMIN` profile exists yet, so supervisor sign-in cannot be exercised until an administrator grants the role.

Granting the supervisor role is an administrative action performed with the server-side credentials, never from Flutter:

```sql
update public.profiles set role = 'SUPERVISOR' where id = '<auth-user-uuid>';
```

## Phase 8 migration

Apply `migrations/005_evidence_integrity_analysis.sql` after the existing migrations. It adds evidence lifecycle, calibration, indicative analysis, hash-chain, and signature metadata. The migration does not add secrets or private keys. Evidence remains in the private `evidence` bucket, and finalized records cannot be updated through the client policy.
