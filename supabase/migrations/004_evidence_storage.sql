insert into storage.buckets (id, name, public)
values ('evidence', 'evidence', false)
on conflict (id) do update set public = false;

create policy "evidence_objects_insert_own"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'evidence'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "evidence_objects_select_own"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'evidence'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
);
