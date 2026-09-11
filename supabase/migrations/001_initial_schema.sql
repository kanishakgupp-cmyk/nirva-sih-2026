create extension if not exists pgcrypto;

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text,
    role text not null default 'OFFICER',
    created_at timestamptz not null default now(),
    constraint profiles_role_check check (role in ('OFFICER', 'SUPERVISOR', 'ADMIN'))
);

create table public.cases (
    id uuid primary key default gen_random_uuid(),
    case_number text unique not null,
    title text not null,
    description text,
    created_by uuid not null references auth.users(id),
    created_at timestamptz not null default now()
);

create table public.kits (
    id uuid primary key default gen_random_uuid(),
    kit_code text unique not null,
    batch_number text not null,
    expiry_date date not null,
    status text not null,
    created_at timestamptz not null default now(),
    constraint kits_status_check check (status in ('ACTIVE', 'INACTIVE', 'RECALLED'))
);

create table public.test_sessions (
    id uuid primary key default gen_random_uuid(),
    test_number text unique not null,
    case_id uuid not null references public.cases(id),
    kit_id uuid not null references public.kits(id),
    operator_id uuid not null references auth.users(id),
    session_nonce text,
    reagent_protocol text,
    started_at timestamptz,
    captured_at timestamptz,
    reaction_time_seconds integer,
    latitude double precision,
    longitude double precision,
    gps_accuracy double precision,
    status text not null,
    created_at timestamptz not null default now(),
    constraint test_sessions_status_check check (
        status in ('CREATED', 'RUNNING', 'CAPTURED', 'ANALYZED', 'FINALIZED', 'INVALID')
    )
);

create table public.evidence_records (
    id uuid primary key default gen_random_uuid(),
    test_id uuid not null references public.test_sessions(id),
    operator_id uuid not null references auth.users(id),
    device_id text,
    captured_at timestamptz,
    latitude double precision,
    longitude double precision,
    gps_accuracy double precision,
    image_path text,
    image_sha256 text,
    image_quality_score double precision,
    blur_score double precision,
    brightness_score double precision,
    glare_score double precision,
    reference_card_status text,
    calibration_status text,
    calibration_error double precision,
    result text,
    confidence double precision,
    model_version text,
    previous_record_hash text,
    record_hash text,
    signature text,
    legal_label text not null default 'INDICATIVE ONLY - LABORATORY CONFIRMATION REQUIRED',
    created_at timestamptz not null default now()
);

create table public.audit_events (
    id uuid primary key default gen_random_uuid(),
    test_id uuid not null references public.test_sessions(id),
    operator_id uuid not null references auth.users(id),
    event_type text not null,
    event_data jsonb,
    created_at timestamptz not null default now()
);

create index cases_created_by_idx on public.cases (created_by);
create index test_sessions_case_id_idx on public.test_sessions (case_id);
create index test_sessions_operator_id_idx on public.test_sessions (operator_id);
create index evidence_records_test_id_idx on public.evidence_records (test_id);
create index audit_events_test_id_idx on public.audit_events (test_id);

alter table public.profiles enable row level security;
alter table public.cases enable row level security;
alter table public.kits enable row level security;
alter table public.test_sessions enable row level security;
alter table public.evidence_records enable row level security;
alter table public.audit_events enable row level security;

create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

create policy "cases_insert_own"
on public.cases
for insert
to authenticated
with check (created_by = auth.uid());

create policy "cases_select_own"
on public.cases
for select
to authenticated
using (created_by = auth.uid());

create policy "kits_select_active"
on public.kits
for select
to authenticated
using (status = 'ACTIVE');

create policy "test_sessions_insert_own"
on public.test_sessions
for insert
to authenticated
with check (operator_id = auth.uid());

create policy "test_sessions_select_own"
on public.test_sessions
for select
to authenticated
using (operator_id = auth.uid());

create policy "evidence_records_insert_own"
on public.evidence_records
for insert
to authenticated
with check (operator_id = auth.uid());

create policy "evidence_records_select_own"
on public.evidence_records
for select
to authenticated
using (operator_id = auth.uid());

create policy "audit_events_insert_own"
on public.audit_events
for insert
to authenticated
with check (operator_id = auth.uid());

create policy "audit_events_select_own"
on public.audit_events
for select
to authenticated
using (operator_id = auth.uid());

insert into public.kits (kit_code, batch_number, expiry_date, status)
values ('NIRVA-DEMO-001', 'DEMO-BATCH-001', date '2030-12-31', 'ACTIVE');
