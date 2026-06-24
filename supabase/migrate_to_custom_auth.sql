-- =============================================================================
-- Migration: Drop Supabase Auth dependency, add custom password auth
--
-- This script:
-- 1. Drops the FK from profiles.id → auth.users(id)
-- 2. Removes the NOT NULL constraint from email (if present)
-- 3. Adds the password column if it doesn't exist
-- 4. Disables RLS on all tables (thesis project uses app-layer auth)
-- 5. Grants anon full access
--
-- Safe to re-run (uses IF NOT EXISTS / IF EXISTS guards).
-- =============================================================================

-- 1) Drop the FK constraint from profiles → auth.users, if it exists
do $$
declare
  constraint_name text;
begin
  select tc.constraint_name into constraint_name
  from information_schema.table_constraints tc
  where tc.table_name = 'profiles' and tc.constraint_type = 'FOREIGN KEY'
  limit 1;

  if constraint_name is not null then
    execute 'alter table public.profiles drop constraint ' || constraint_name;
  end if;
end $$;

-- 2) Add password column if it doesn't exist
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'profiles' and column_name = 'password'
  ) then
    alter table public.profiles add column password text not null default '';
  end if;
end $$;

-- 3) Ensure email is not null
alter table public.profiles alter column email set not null;

-- 4) Add unique index on lower(email) if it doesn't exist
do $$
begin
  if not exists (
    select 1 from pg_indexes
    where indexname = 'profiles_email_uidx'
  ) then
    create unique index profiles_email_uidx on public.profiles(lower(email));
  end if;
end $$;

-- 5) Disable RLS on all tables (custom auth at app layer)
alter table public.cooperatives        disable row level security;
alter table public.profiles            disable row level security;
alter table public.farms               disable row level security;
alter table public.crops               disable row level security;
alter table public.crop_declarations   disable row level security;
alter table public.declaration_reviews disable row level security;
alter table public.expenses            disable row level security;
alter table public.production_reports  disable row level security;
alter table public.logbook_entries     disable row level security;
alter table public.calamity_reports    disable row level security;
alter table public.market_channels     disable row level security;
alter table public.market_prices       disable row level security;
alter table public.demand_baselines    disable row level security;

-- 6) Grant anon full access (RLS is off, so this is the access control)
grant usage on schema public to anon, authenticated;
grant all privileges on all tables    in schema public to anon, authenticated;
grant all privileges on all sequences in schema public to anon, authenticated;
alter default privileges in schema public
  grant all on tables    to anon, authenticated;
alter default privileges in schema public
  grant all on sequences to anon, authenticated;

-- 7) Update the 5 named login accounts with plain-text password
update public.profiles set password = 'AgriSense123!'
where email in (
  'mao@agrisense.ph',
  'baw@agrisense.ph',
  'tech@agrisense.ph',
  'coop@agrisense.ph',
  'farmer@agrisense.ph'
);

-- 8) Update 50 background farmers with plain-text password
update public.profiles set password = 'AgriSense123!'
where email like 'bg%@agrisense.local';
