-- =============================================================================
-- AgriSense — Integrated Agricultural Decision Support System (IADSS)
-- Supabase / PostgreSQL schema (Third Normal Form) — ALL PORTALS
--
-- Authentication: custom (profiles table with plain-text password column).
-- Supabase Auth (auth.users) is NOT used; the Flutter app queries
-- profiles WHERE email=? AND password=? directly via the anon key.
--
-- Row Level Security is DISABLED on all tables. Access is governed at the
-- application layer (the anon key is used for all requests; only authorised
-- portals are distributed). Explicit GRANTs ensure the anon role can read
-- and write every table.
--
-- Idempotent: safe to re-run.
-- =============================================================================

-- Extensions ------------------------------------------------------------------
create extension if not exists "pgcrypto";   -- gen_random_uuid()

-- Enumerated types ------------------------------------------------------------
do $$ begin
  create type user_role as enum
    ('farmer','cooperative','mao','technician','baw');
exception when duplicate_object then null; end $$;

do $$ begin
  create type declaration_status as enum
    ('draft','pending','baw_approved','technician_verified',
     'approved','correction_requested','rejected','harvested');
exception when duplicate_object then null; end $$;

do $$ begin
  create type expense_category as enum
    ('seed','fertilizer','labor','irrigation','transport',
     'pesticide','equipment','other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type calamity_type as enum
    ('typhoon','flood','drought','pest','disease','landslide','other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type verification_status as enum
    ('submitted','under_review','verified','endorsed','declined');
exception when duplicate_object then null; end $$;

do $$ begin
  create type activity_type as enum
    ('land_prep','planting','fertilizing','irrigation','weeding',
     'pest_control','scouting','harvesting','other');
exception when duplicate_object then null; end $$;

-- =============================================================================
-- Governance & support
-- =============================================================================

create table if not exists public.cooperatives (
  id                      uuid primary key default gen_random_uuid(),
  name                    text not null,
  barangay                text not null,
  contact_person          text,
  contact_number          text,
  member_count            integer not null default 0,
  buy_back_capacity_tons  numeric,
  created_at              timestamptz not null default now()
);

-- User accounts (replaces auth.users + profiles; password stored as plain text
-- for thesis-project simplicity). Email is the login identifier.
create table if not exists public.profiles (
  id              uuid primary key default gen_random_uuid(),
  email           text not null,
  password        text not null default '',
  full_name       text not null,
  role            user_role not null default 'farmer',
  contact_number  text,
  barangay        text,
  cooperative_id  uuid references public.cooperatives(id) on delete set null,
  avatar_url      text,
  created_at      timestamptz not null default now()
);
create unique index if not exists profiles_email_uidx on public.profiles(lower(email));

-- Farm profiling (Phase 1) ----------------------------------------------------
create table if not exists public.farms (
  id                   uuid primary key default gen_random_uuid(),
  owner_id             uuid not null references public.profiles(id) on delete cascade,
  name                 text not null,
  barangay             text not null,
  total_area_ha        numeric not null,
  latitude             numeric,
  longitude            numeric,
  soil_type            text,
  previous_crops       text[] not null default '{}',
  previous_activities  text,
  photo_urls           text[] not null default '{}',
  created_at           timestamptz not null default now()
);
create index if not exists farms_owner_idx on public.farms(owner_id);

-- Reference crops (agronomic + economic baselines) ----------------------------
create table if not exists public.crops (
  id                    text primary key,
  name                  text not null,
  category              text,
  suitable_seasons      text[] not null default '{}',
  growth_duration_days  integer not null,
  baseline_yield_per_ha numeric not null,
  unit                  text not null default 'kg',
  baseline_price_per_kg numeric not null,
  projected_demand_tons numeric not null,
  companions            text[] not null default '{}',
  land_suitability      numeric not null default 0.8
);

-- Crop declarations / farming projects (Phase 2) ------------------------------
create table if not exists public.crop_declarations (
  id                     uuid primary key default gen_random_uuid(),
  farmer_id              uuid not null references public.profiles(id) on delete cascade,
  farm_id                uuid not null references public.farms(id) on delete cascade,
  crop_id                text not null references public.crops(id),
  variety                text not null,
  area_ha                numeric not null,
  planting_date          date not null,
  expected_harvest_date  date not null,
  expected_yield_kg      numeric not null,
  barangay               text not null,
  status                 declaration_status not null default 'pending',
  companion_crop_ids     text[] not null default '{}',
  projected_price_per_kg numeric,
  notes                  text,
  reviewer_note          text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index if not exists decl_farmer_idx   on public.crop_declarations(farmer_id);
create index if not exists decl_crop_idx      on public.crop_declarations(crop_id);
create index if not exists decl_barangay_idx  on public.crop_declarations(barangay);
create index if not exists decl_status_idx    on public.crop_declarations(status);

-- Validation audit trail (web portal) -----------------------------------------
create table if not exists public.declaration_reviews (
  id             uuid primary key default gen_random_uuid(),
  declaration_id uuid not null references public.crop_declarations(id) on delete cascade,
  reviewer_id    uuid not null references public.profiles(id),
  reviewer_role  user_role not null,
  from_status    declaration_status,
  to_status      declaration_status not null,
  note           text,
  created_at     timestamptz not null default now()
);
create index if not exists reviews_decl_idx on public.declaration_reviews(declaration_id);

-- Economic tracking (Objective 2) ---------------------------------------------
create table if not exists public.expenses (
  id              uuid primary key default gen_random_uuid(),
  declaration_id  uuid not null references public.crop_declarations(id) on delete cascade,
  farmer_id       uuid not null references public.profiles(id) on delete cascade,
  category        expense_category not null,
  description     text not null,
  amount          numeric not null check (amount >= 0),
  incurred_on     date not null,
  created_at      timestamptz not null default now()
);
create index if not exists expenses_decl_idx on public.expenses(declaration_id);

create table if not exists public.production_reports (
  id                  uuid primary key default gen_random_uuid(),
  declaration_id      uuid not null references public.crop_declarations(id) on delete cascade,
  farmer_id           uuid not null references public.profiles(id) on delete cascade,
  actual_yield_kg     numeric not null,
  actual_price_per_kg numeric not null,
  harvested_on        date not null,
  loss_kg             numeric not null default 0,
  notes               text,
  created_at          timestamptz not null default now()
);
create unique index if not exists prod_decl_uidx
  on public.production_reports(declaration_id);

-- Digital logbook & incident reporting (Objective 4) --------------------------
create table if not exists public.logbook_entries (
  id              uuid primary key default gen_random_uuid(),
  farmer_id       uuid not null references public.profiles(id) on delete cascade,
  declaration_id  uuid references public.crop_declarations(id) on delete set null,
  activity        activity_type not null,
  title           text not null,
  performed_on    date not null,
  details         text,
  input_used      text,
  quantity        numeric,
  unit            text,
  cost            numeric,
  created_at      timestamptz not null default now()
);
create index if not exists logbook_farmer_idx on public.logbook_entries(farmer_id);

create table if not exists public.calamity_reports (
  id                   uuid primary key default gen_random_uuid(),
  farmer_id            uuid not null references public.profiles(id) on delete cascade,
  declaration_id       uuid references public.crop_declarations(id) on delete set null,
  crop_id              text,
  barangay             text not null,
  type                 calamity_type not null,
  occurred_on          date not null,
  affected_area_ha     numeric not null,
  loss_percent         numeric not null check (loss_percent between 0 and 100),
  estimated_loss_value numeric,
  status               verification_status not null default 'submitted',
  description          text,
  photo_urls           text[] not null default '{}',
  verifier_note        text,
  created_at           timestamptz not null default now()
);
create index if not exists calamity_farmer_idx   on public.calamity_reports(farmer_id);
create index if not exists calamity_barangay_idx  on public.calamity_reports(barangay);

-- Supply chain channels (Objective 3) -----------------------------------------
create table if not exists public.market_channels (
  id              uuid primary key default gen_random_uuid(),
  cooperative_id  uuid not null references public.cooperatives(id) on delete cascade,
  name            text not null,
  type            text not null default 'buy_back',
  capacity_tons   numeric not null,
  crop_ids        text[] not null default '{}',
  price_per_kg    numeric,
  contact         text,
  notes           text,
  created_at      timestamptz not null default now()
);
create index if not exists channels_coop_idx on public.market_channels(cooperative_id);

-- Calibration inputs (Objectives 1 & 2): price history + demand baselines ------
create table if not exists public.market_prices (
  id            uuid primary key default gen_random_uuid(),
  crop_id       text not null references public.crops(id) on delete cascade,
  price_per_kg  numeric not null,
  recorded_on   date not null,
  market        text
);
create index if not exists prices_crop_idx on public.market_prices(crop_id);

create table if not exists public.demand_baselines (
  crop_id             text primary key references public.crops(id) on delete cascade,
  annual_demand_tons  numeric not null,
  updated_at          timestamptz not null default now()
);

-- =============================================================================
-- Triggers
-- =============================================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists decl_touch on public.crop_declarations;
create trigger decl_touch before update on public.crop_declarations
  for each row execute function public.touch_updated_at();

-- =============================================================================
-- Row Level Security — DISABLED (custom auth, thesis project)
-- =============================================================================
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

-- =============================================================================
-- Grants — allow the anon (unauthenticated) role full access since RLS is off
-- =============================================================================
grant usage on schema public to anon, authenticated;
grant all privileges on all tables    in schema public to anon, authenticated;
grant all privileges on all sequences in schema public to anon, authenticated;
alter default privileges in schema public
  grant all on tables    to anon, authenticated;
alter default privileges in schema public
  grant all on sequences to anon, authenticated;

-- =============================================================================
-- Seed reference crops (mirrors lib/core/constants/app_constants.dart).
-- =============================================================================
insert into public.crops
  (id, name, category, suitable_seasons, growth_duration_days,
   baseline_yield_per_ha, unit, baseline_price_per_kg,
   projected_demand_tons, companions, land_suitability)
values
  ('ampalaya','Ampalaya','Vegetable','{dry,wet}',70,12000,'kg',45,500,'{corn,string_beans}',0.82),
  ('eggplant','Eggplant','Vegetable','{dry,wet}',80,18000,'kg',40,620,'{string_beans,okra}',0.88),
  ('okra','Okra','Vegetable','{dry,wet}',55,9000,'kg',35,410,'{eggplant,ampalaya}',0.84),
  ('string_beans','String Beans','Legume','{dry,wet}',60,8000,'kg',50,360,'{ampalaya,eggplant,corn}',0.86),
  ('tomato','Tomato','Vegetable','{dry}',75,20000,'kg',38,540,'{okra,string_beans}',0.79),
  ('corn','Sweet Corn','Cereal','{wet}',90,6000,'kg',22,700,'{string_beans,ampalaya}',0.81),
  ('squash','Squash','Vegetable','{dry,wet}',85,15000,'kg',25,480,'{corn,okra}',0.83),
  ('pechay','Pechay','Leafy Vegetable','{dry,wet}',35,11000,'kg',30,300,'{okra,eggplant}',0.80)
on conflict (id) do nothing;
