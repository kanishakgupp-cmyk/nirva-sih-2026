create policy "test_sessions_update_own"
on public.test_sessions
for update
to authenticated
using (operator_id = auth.uid())
with check (operator_id = auth.uid());
