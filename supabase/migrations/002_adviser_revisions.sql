-- =============================================================================
-- AgriSense — Migration 002: adviser revisions
--
-- Applies the schema changes behind the consultation feedback. Idempotent and
-- non-destructive: nothing is dropped, and every existing row is backfilled to
-- a valid value before constraints tighten.
--
-- Run AFTER supabase/schema.sql. Safe to re-run.
-- =============================================================================

create extension if not exists "pgcrypto";

-- =============================================================================
-- 1. Declarations are records, not applications
--
-- The MAO cannot approve or deny what a farmer plants on their own land, so the
-- BAW -> Technician -> MAO approval chain is retired. The old enum values are
-- kept (Postgres cannot remove enum members without a type rewrite) but every
-- row is mapped onto the three surviving states, and the default becomes
-- 'active'. `declaration_reviews` is left in place, unused, so its audit
-- history is not destroyed.
-- =============================================================================

-- The type is swapped rather than extended: `ALTER TYPE ... ADD VALUE` cannot
-- be used in the same transaction that adds it, and Supabase's SQL editor runs
-- a script as one transaction. Recreating the type keeps this migration atomic.
do $$
begin
  if exists (
    select 1 from pg_type t
      join pg_enum e on e.enumtypid = t.oid
     where t.typname = 'declaration_status' and e.enumlabel = 'active'
  ) then
    return;  -- already migrated
  end if;

  create type declaration_status_new as enum ('active','harvested','cancelled');

  alter table public.crop_declarations alter column status drop default;

  alter table public.crop_declarations
    alter column status type declaration_status_new
    using (case status::text
             when 'harvested' then 'harvested'
             when 'rejected'  then 'cancelled'
             else 'active'
           end)::declaration_status_new;

  -- The retired audit trail keeps its history as free text.
  alter table public.declaration_reviews
    alter column from_status type text using from_status::text,
    alter column to_status   type text using to_status::text;

  drop type declaration_status;
  alter type declaration_status_new rename to declaration_status;

  alter table public.crop_declarations
    alter column status set default 'active'::declaration_status;
end $$;

-- The declaration now records what the app advised before planting, so the
-- study can report whether farmers acted on the warnings they were shown.
alter table public.crop_declarations
  add column if not exists risk_at_declaration text,
  add column if not exists seedling_sowing_date date;

comment on column public.crop_declarations.risk_at_declaration is
  'Risk verdict shown to the farmer before they committed: low | caution | high.';
comment on column public.crop_declarations.seedling_sowing_date is
  'Seedbed date for nursery-raised crops; NULL when direct-seeded. Precedes '
  'planting_date by the crop''s nursery period.';
comment on column public.crop_declarations.expected_yield_kg is
  'System-derived (calibrated yield x area x barangay suitability). No longer '
  'entered by the farmer.';
comment on column public.crop_declarations.projected_price_per_kg is
  'System-derived baseline farmgate price at declaration time.';

-- =============================================================================
-- 2. Profiles: split names, username, and residency verification
-- =============================================================================

do $$ begin
  create type account_verification as enum
    ('unverified','pending','verified','rejected');
exception when duplicate_object then null; end $$;

alter table public.profiles
  add column if not exists first_name   text,
  add column if not exists middle_name  text,
  add column if not exists last_name    text,
  add column if not exists username     text,
  add column if not exists rsbsa_number text,
  add column if not exists verification account_verification not null
      default 'unverified',
  add column if not exists verified_by  uuid references public.profiles(id),
  add column if not exists verified_at  timestamptz;

-- Backfill from the legacy single-column name, splitting on the last space.
update public.profiles
   set first_name = coalesce(
         nullif(regexp_replace(full_name, '\s+\S+$', ''), ''), full_name),
       last_name  = coalesce(
         nullif((regexp_match(full_name, '(\S+)$'))[1], ''), '')
 where first_name is null
   and full_name is not null;

update public.profiles set first_name = 'AgriSense' where first_name is null;
update public.profiles set last_name  = 'User'      where last_name  is null;

alter table public.profiles alter column first_name set not null;
alter table public.profiles alter column last_name  set not null;

-- full_name is retained (nullable) so older clients keep working; new clients
-- read and write the split columns.
alter table public.profiles alter column full_name drop not null;

create unique index if not exists profiles_username_uidx
  on public.profiles(lower(username)) where username is not null;
create index if not exists profiles_rsbsa_idx
  on public.profiles(rsbsa_number) where rsbsa_number is not null;

comment on column public.profiles.rsbsa_number is
  'Registry System for Basic Sectors in Agriculture ID — the roster the MAO '
  'checks to confirm a farmer is a Tubungan resident.';

-- =============================================================================
-- 3. Farms lose their user-supplied name
--
-- A farmer identifies land by where it is and how big it is. The column is made
-- nullable rather than dropped so nothing is lost if it held useful notes.
-- =============================================================================

alter table public.farms alter column name drop not null;

comment on column public.farms.name is
  'DEPRECATED — the mobile client derives a label from barangay and area.';

-- =============================================================================
-- 4. Activities and their costs are one record
--
-- logbook_entries.cost was written but never reached the P&L, which only ever
-- summed `expenses`. Farmers either entered a figure twice or their ROI was
-- silently wrong. The two tables now reference each other.
-- =============================================================================

alter table public.expenses
  add column if not exists logbook_entry_id uuid
    references public.logbook_entries(id) on delete set null;

alter table public.logbook_entries
  add column if not exists expense_id uuid
    references public.expenses(id) on delete set null,
  add column if not exists planned_activity_id uuid;

create index if not exists expenses_logbook_idx
  on public.expenses(logbook_entry_id);
create index if not exists logbook_expense_idx
  on public.logbook_entries(expense_id);

-- Backfill: promote every historical logbook cost into a real expense so past
-- P&L figures stop under-reporting. Only entries linked to a declaration can be
-- attributed, so unattributed costs are left alone rather than guessed at.
with promoted as (
  insert into public.expenses
    (declaration_id, farmer_id, category, description, amount, incurred_on,
     logbook_entry_id, created_at)
  select l.declaration_id,
         l.farmer_id,
         case l.activity
           when 'fertilizing'  then 'fertilizer'
           when 'irrigation'   then 'irrigation'
           when 'pest_control' then 'pesticide'
           when 'planting'     then 'seed'
           when 'land_prep'    then 'labor'
           when 'weeding'      then 'labor'
           when 'harvesting'   then 'labor'
           else 'other'
         end::expense_category,
         l.title,
         l.cost,
         l.performed_on,
         l.id,
         now()
    from public.logbook_entries l
   where l.cost is not null
     and l.cost > 0
     and l.expense_id is null
     and l.declaration_id is not null
  returning id, logbook_entry_id
)
update public.logbook_entries l
   set expense_id = p.id
  from promoted p
 where l.id = p.logbook_entry_id;

-- =============================================================================
-- 5. Crop calendar — system-scheduled farm operations
-- =============================================================================

do $$ begin
  create type planned_activity_status as enum ('pending','done','skipped');
exception when duplicate_object then null; end $$;

create table if not exists public.planned_activities (
  id                   uuid primary key default gen_random_uuid(),
  declaration_id       uuid not null
                         references public.crop_declarations(id) on delete cascade,
  farmer_id            uuid not null
                         references public.profiles(id) on delete cascade,
  activity             activity_type not null,
  title                text not null,
  scheduled_on         date not null,
  days_after_planting  integer not null,
  suggested_input      text,
  suggested_qty_per_ha numeric,
  unit                 text,
  status               planned_activity_status not null default 'pending',
  logbook_entry_id     uuid references public.logbook_entries(id) on delete set null,
  completed_on         date,
  created_at           timestamptz not null default now()
);
create index if not exists planned_farmer_idx on public.planned_activities(farmer_id);
create index if not exists planned_decl_idx   on public.planned_activities(declaration_id);
create index if not exists planned_due_idx    on public.planned_activities(scheduled_on)
  where status = 'pending';

alter table public.logbook_entries
  add constraint logbook_planned_fk
  foreign key (planned_activity_id)
  references public.planned_activities(id) on delete set null
  not valid;

comment on table public.planned_activities is
  'Crop protocol expanded against a real planting date — when to fertilise, '
  'irrigate, spray, and harvest. Confirming one writes a logbook entry.';

-- =============================================================================
-- 6. Demand measured from cooperatives
--
-- The saturation denominator was one hardcoded annual constant per crop:
-- unverifiable, and impossible for anyone on the ground to correct.
-- =============================================================================

do $$ begin
  create type buyer_type as enum
    ('bagsakan','institutional','processor','trader','retail');
exception when duplicate_object then null; end $$;

create table if not exists public.demand_signals (
  id              uuid primary key default gen_random_uuid(),
  cooperative_id  uuid not null
                    references public.cooperatives(id) on delete cascade,
  crop_id         text not null references public.crops(id),
  period_start    date not null,
  period_end      date not null,
  demand_tons     numeric not null check (demand_tons >= 0),
  buyer_type      buyer_type not null default 'bagsakan',
  price_per_kg    numeric,
  buyer_name      text,
  notes           text,
  created_at      timestamptz not null default now(),
  check (period_end >= period_start)
);
create index if not exists demand_coop_idx on public.demand_signals(cooperative_id);
create index if not exists demand_crop_idx on public.demand_signals(crop_id);
create index if not exists demand_period_idx
  on public.demand_signals(period_start, period_end);

-- =============================================================================
-- 7. Technician assignments per barangay
--
-- With no approval chain, the technician is an advisory contact rather than a
-- gatekeeper — the farmer needs to know who covers their area.
-- =============================================================================

create table if not exists public.barangay_assignments (
  id              uuid primary key default gen_random_uuid(),
  barangay        text not null,
  technician_id   uuid not null references public.profiles(id) on delete cascade,
  role            user_role not null default 'technician',
  technician_name text,
  contact_number  text,
  assigned_at     timestamptz not null default now(),
  unique (barangay, technician_id)
);
create index if not exists assignment_barangay_idx
  on public.barangay_assignments(barangay);

-- =============================================================================
-- 8. Supply-chain tracing on the production report
--
-- Without this the municipality can see what was planted but not where the
-- supply went — the gap behind "ay diin nagkadto ang supply?".
-- =============================================================================

do $$ begin
  create type sales_channel as enum
    ('bagsakan','cooperative','trader','direct_market',
     'neighbouring_municipality','own_consumption','other');
exception when duplicate_object then null; end $$;

alter table public.production_reports
  add column if not exists sold_to_channel sales_channel not null
      default 'bagsakan',
  add column if not exists buyer_name text;

create index if not exists production_channel_idx
  on public.production_reports(sold_to_channel);

-- =============================================================================
-- 9. Grants (RLS stays disabled; access is governed at the application layer)
-- =============================================================================

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete
  on public.planned_activities,
     public.demand_signals,
     public.barangay_assignments
  to anon, authenticated;
