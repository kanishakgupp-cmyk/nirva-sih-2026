-- 008_test_session_state_machine.sql
-- Enforce the officer workflow at the database boundary.

create or replace function public.enforce_test_session_state_transition()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'UPDATE' and new.status is distinct from old.status then
        if not (
            (old.status = 'CREATED' and new.status in ('RUNNING', 'INVALID'))
            or (old.status = 'RUNNING' and new.status in ('CAPTURED', 'INVALID'))
            or (old.status = 'CAPTURED' and new.status in ('ANALYZED', 'INVALID'))
            or (old.status = 'ANALYZED' and new.status in ('FINALIZED', 'INVALID'))
        ) then
            raise exception 'Invalid test session state transition: % -> %', old.status, new.status;
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists test_sessions_state_transition on public.test_sessions;

create trigger test_sessions_state_transition
before update on public.test_sessions
for each row
execute function public.enforce_test_session_state_transition();

create or replace function public.audit_test_session_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        insert into public.audit_events (test_id, operator_id, event_type, event_data)
        values (new.id, new.operator_id, 'TEST_SESSION_CREATED', jsonb_build_object('status', new.status));
    elsif new.status is distinct from old.status then
        insert into public.audit_events (test_id, operator_id, event_type, event_data)
        values (
            new.id,
            new.operator_id,
            'TEST_SESSION_STATUS_CHANGED',
            jsonb_build_object('previous_status', old.status, 'new_status', new.status)
        );
    end if;
    return new;
end;
$$;

drop trigger if exists audit_test_session_changes on public.test_sessions;

create trigger audit_test_session_changes
after insert or update on public.test_sessions
for each row
execute function public.audit_test_session_changes();