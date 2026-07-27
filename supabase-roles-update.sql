-- ============================================================
-- Roles update: managers vs reps
--   managers  -> see everything, assign, import, delete
--   reps      -> see ONLY leads assigned to them
-- Safe to run on the live database (does not touch lead data).
-- NOTE: create Seb's login BEFORE running this (seb@local.com),
--       or just re-run this script after you create it.
-- ============================================================

-- role column on profiles (everyone starts as 'rep')
alter table public.profiles
  add column if not exists role text not null default 'rep'
  check (role in ('manager','rep'));

-- helper: is the signed-in user a manager?
create or replace function public.is_manager()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'manager');
$$;

-- promote the managers
update public.profiles set role = 'manager'
where email in ('jenna@local.com', 'seb@local.com');

-- ---------- leads: replace the open policy with role-aware ones ----------
drop policy if exists "leads: full access for signed-in team" on public.leads;
drop policy if exists "leads: managers all, reps assigned (select)" on public.leads;
drop policy if exists "leads: managers all, reps assigned (insert)" on public.leads;
drop policy if exists "leads: managers all, reps assigned (update)" on public.leads;
drop policy if exists "leads: managers only (delete)" on public.leads;

create policy "leads: managers all, reps assigned (select)"
  on public.leads for select to authenticated
  using (public.is_manager() or assigned_to = auth.uid());

-- reps may add a lead, but only assigned to themselves
create policy "leads: managers all, reps assigned (insert)"
  on public.leads for insert to authenticated
  with check (public.is_manager() or assigned_to = auth.uid());

-- reps may work their own leads but cannot reassign them away
create policy "leads: managers all, reps assigned (update)"
  on public.leads for update to authenticated
  using (public.is_manager() or assigned_to = auth.uid())
  with check (public.is_manager() or assigned_to = auth.uid());

create policy "leads: managers only (delete)"
  on public.leads for delete to authenticated
  using (public.is_manager());

-- ---------- notes: visibility follows the lead ----------
drop policy if exists "notes: full access for signed-in team" on public.lead_notes;
drop policy if exists "notes: visible with lead (select)" on public.lead_notes;
drop policy if exists "notes: visible with lead (insert)" on public.lead_notes;
drop policy if exists "notes: managers only (delete)" on public.lead_notes;

create policy "notes: visible with lead (select)"
  on public.lead_notes for select to authenticated
  using (exists (select 1 from public.leads l where l.id = lead_id));

create policy "notes: visible with lead (insert)"
  on public.lead_notes for insert to authenticated
  with check (exists (select 1 from public.leads l where l.id = lead_id));

create policy "notes: managers only (delete)"
  on public.lead_notes for delete to authenticated
  using (public.is_manager());

-- show the team + roles so you can confirm
select full_name, email, role from public.profiles order by role, full_name;
