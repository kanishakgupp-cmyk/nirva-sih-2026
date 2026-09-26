-- Allow a retried client upload to resolve to the one server-created record.

alter table public.evidence_records
    add column if not exists client_operation_id text;

create unique index if not exists evidence_records_operator_operation_idx
    on public.evidence_records (operator_id, client_operation_id)
    where client_operation_id is not null;

comment on column public.evidence_records.client_operation_id is
    'Client-generated operation UUID used to make evidence upload retries idempotent.';