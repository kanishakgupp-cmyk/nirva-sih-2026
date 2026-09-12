alter table public.evidence_records
    add column if not exists evidence_status text not null default 'CAPTURED',
    add column if not exists normalized_image_path text,
    add column if not exists analysis_status text,
    add column if not exists analysis_result text,
    add column if not exists analysis_confidence double precision,
    add column if not exists analysis_uncertainty double precision,
    add column if not exists analysis_model_version text,
    add column if not exists analysis_features jsonb,
    add column if not exists analysis_explanation jsonb,
    add column if not exists analysis_completed_at timestamptz,
    add column if not exists signature_algorithm text,
    add column if not exists key_id text;

alter table public.evidence_records
    drop constraint if exists evidence_records_status_check;

alter table public.evidence_records
    add constraint evidence_records_status_check check (
        evidence_status in ('CAPTURED', 'VALIDATING', 'ANALYZED', 'FINALIZED', 'INVALID')
    );

create index if not exists evidence_records_operator_status_idx
    on public.evidence_records (operator_id, evidence_status);

create index if not exists evidence_records_record_hash_idx
    on public.evidence_records (record_hash);

comment on column public.evidence_records.analysis_result is
    'Indicative demonstration classification only; never a laboratory result.';
comment on column public.evidence_records.record_hash is
    'SHA-256 hash-chain link over canonical record data and previous_record_hash.';
comment on column public.evidence_records.signature is
    'Optional device-bound signature; private keys never belong in this database.';

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'evidence_records'
          and policyname = 'evidence_records_update_own_non_finalized'
    ) then
        create policy "evidence_records_update_own_non_finalized"
        on public.evidence_records
        for update
        to authenticated
        using (operator_id = auth.uid() and evidence_status <> 'FINALIZED')
        with check (operator_id = auth.uid());
    end if;
end
$$;
