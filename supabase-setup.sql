-- ============================================================
-- Lead Tracker — Supabase setup script
-- Run this ONCE in your Supabase project:
--   Dashboard → SQL Editor → New query → paste this → Run
-- ============================================================

-- ---------- Profiles (one row per login, holds display name) ----------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null default '',
  email      text,
  role       text not null default 'rep' check (role in ('manager','rep')),
  created_at timestamptz not null default now()
);

-- helper: is the signed-in user a manager?
create or replace function public.is_manager()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'manager');
$$;

alter table public.profiles enable row level security;

create policy "profiles: read all"
  on public.profiles for select to authenticated using (true);

create policy "profiles: update own"
  on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

-- Auto-create a profile whenever a user is added (dashboard or invite)
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', initcap(replace(split_part(new.email, '@', 1), '.', ' '))),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for any users that already exist
insert into public.profiles (id, full_name, email)
select u.id,
       coalesce(u.raw_user_meta_data->>'full_name', initcap(replace(split_part(u.email, '@', 1), '.', ' '))),
       u.email
from auth.users u
on conflict (id) do nothing;

-- ---------- Leads ----------
create table public.leads (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  name           text not null,
  phone          text not null default '',
  email          text not null default '',
  source         text not null default '',
  interest       text not null default '',   -- building type / size they want
  location       text not null default '',   -- city / county / state
  value          numeric not null default 0, -- estimated deal value
  priority       text not null default 'standard'
                 check (priority in ('hot','warm','standard','longterm','nurture')),
  stage          text not null default 'new'
                 check (stage in ('new','attempting','quoted','active','future','ready','won','lost','dq')),
  assigned_to    uuid references public.profiles (id) on delete set null,
  next_follow_up date
);

create index leads_stage_idx    on public.leads (stage);
create index leads_assigned_idx on public.leads (assigned_to);

alter table public.leads enable row level security;

-- managers see everything; reps only their assigned leads
create policy "leads: managers all, reps assigned (select)"
  on public.leads for select to authenticated
  using (public.is_manager() or assigned_to = auth.uid());

create policy "leads: managers all, reps assigned (insert)"
  on public.leads for insert to authenticated
  with check (public.is_manager() or assigned_to = auth.uid());

create policy "leads: managers all, reps assigned (update)"
  on public.leads for update to authenticated
  using (public.is_manager() or assigned_to = auth.uid())
  with check (public.is_manager() or assigned_to = auth.uid());

create policy "leads: managers only (delete)"
  on public.leads for delete to authenticated
  using (public.is_manager());

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger leads_touch_updated
  before update on public.leads
  for each row execute function public.touch_updated_at();

-- ---------- Notes / activity log ----------
create table public.lead_notes (
  id         uuid primary key default gen_random_uuid(),
  lead_id    uuid not null references public.leads (id) on delete cascade,
  author     uuid references public.profiles (id) on delete set null,
  body       text not null,
  kind       text not null default 'note' check (kind in ('note','system')),
  created_at timestamptz not null default now()
);

create index lead_notes_lead_idx on public.lead_notes (lead_id, created_at desc);

alter table public.lead_notes enable row level security;

-- note visibility follows the lead
create policy "notes: visible with lead (select)"
  on public.lead_notes for select to authenticated
  using (exists (select 1 from public.leads l where l.id = lead_id));

create policy "notes: visible with lead (insert)"
  on public.lead_notes for insert to authenticated
  with check (exists (select 1 from public.leads l where l.id = lead_id));

create policy "notes: managers only (delete)"
  on public.lead_notes for delete to authenticated
  using (public.is_manager());

-- ---------- Realtime (live sync between reps) ----------
alter publication supabase_realtime add table public.leads;
alter publication supabase_realtime add table public.lead_notes;
