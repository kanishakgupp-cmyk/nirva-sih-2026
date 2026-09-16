-- 007_supervisor_hardening.sql
-- Forward-only hardening for Phase 9 supervisor review + evidence immutability.
-- Does not rewrite history: 001-006 remain the recorded baseline.

-- 1. Kit association is attached after the test session is created.
--    Dropping NOT NULL aligns the schema of record with the verified Phase 4 flow
--    (create session -> verify/scan kit -> attach kit). No data is deleted.
alter table public.test_sessions
    alter column kit_id drop not null;

comment on column public.test_sessions.kit_id is
    'Kit attached after verification; null until a kit is scanned or entered.';

-- 2. Allow the explicit EXPIRED kit status alongside derived expiry_date checks.
alter table public.kits
    drop constraint if exists kits_status_check;

alter table public.kits
    add constraint kits_status_check check (
        status in ('ACTIVE', 'INACTIVE', 'RECALLED', 'EXPIRED')
    );

-- 3. Review fields are server-owned. Client (anon/authenticated) writes are neutralised;
--    trusted backend (service_role) writes pass through unchanged.
create or replace function public.evidence_records_guard_review_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        if current_user in ('anon', 'authenticated') then
            new.review_status := 'PENDING';
            new.review_reason := null;
            new.reviewed_by := null;
            new.reviewed_at := null;
        end if;
    elsif tg_op = 'UPDATE' then
        if current_user in ('anon', 'authenticated') then
            new.review_status := old.review_status;
            new.review_reason := old.review_reason;
            new.reviewed_by := old.reviewed_by;
            new.reviewed_at := old.reviewed_at;
        end if;

        -- Finalized evidence is immutable. Only the supervisor review fields may move.
        if old.evidence_status = 'FINALIZED' then
            if (to_jsonb(new) - 'review_status' - 'review_reason' - 'reviewed_by' - 'reviewed_at')
               is distinct from
               (to_jsonb(old) - 'review_status' - 'review_reason' - 'reviewed_by' - 'reviewed_at') then
                raise exception
                    'Finalized evidence is immutable; only supervisor review fields may change.';
            end if;
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists evidence_records_guard_review_fields on public.evidence_records;

create trigger evidence_records_guard_review_fields
before insert or update on public.evidence_records
for each row
execute function public.evidence_records_guard_review_fields();

-- Defence in depth: also deny the review columns at the privilege level for API clients.
revoke update (review_status, review_reason, reviewed_by, reviewed_at)
    on public.evidence_records from anon, authenticated;

grant update (review_status, review_reason, reviewed_by, reviewed_at)
    on public.evidence_records to service_role;

-- 4. Flag and return always carry an operator-visible reason.
--    NOT VALID keeps pre-existing prototype rows untouched while enforcing new writes.
alter table public.evidence_records
    drop constraint if exists evidence_records_review_reason_required_check;

alter table public.evidence_records
    add constraint evidence_records_review_reason_required_check
    check (
        review_status not in ('FLAGGED', 'RETURNED')
        or (review_reason is not null and length(btrim(review_reason)) > 0)
    ) not valid;

comment on constraint evidence_records_review_reason_required_check on public.evidence_records is
    'Supervisor flag/return decisions must record a review reason (server-enforced).';
