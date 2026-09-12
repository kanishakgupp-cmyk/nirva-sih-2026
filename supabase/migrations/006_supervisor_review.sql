alter table public.evidence_records
    add column if not exists review_status text not null default 'PENDING',
    add column if not exists review_reason text,
    add column if not exists reviewed_by uuid references auth.users(id),
    add column if not exists reviewed_at timestamptz;

alter table public.evidence_records
    drop constraint if exists evidence_records_review_status_check;

alter table public.evidence_records
    add constraint evidence_records_review_status_check check (
        review_status in ('PENDING', 'APPROVED', 'FLAGGED', 'RETURNED')
    );

create index if not exists evidence_records_review_status_idx
    on public.evidence_records (review_status, captured_at desc);

comment on column public.evidence_records.review_status is
    'Supervisor workflow status; separate from immutable evidence and analysis lifecycle fields.';
comment on column public.evidence_records.review_reason is
    'Supervisor-provided review context; does not alter captured evidence.';