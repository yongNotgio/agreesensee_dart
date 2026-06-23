-- =============================================================================
-- AgriSense — Integrated Agricultural Decision Support System (IADSS)
-- Supabase / PostgreSQL schema (Third Normal Form)
--
-- This is the data contract the Flutter mobile client maps onto. Every table
-- here corresponds 1:1 to a Dart model in `lib/models/` and a repository in
-- `lib/repositories/`. Run this in the Supabase SQL editor to provision the
-- backend, then launch the app with:
--
--   flutter run \
--     --dart-define=SUPABASE_URL=https://<project>.supabase.co \
--     --dart-define=SUPABASE_ANON_KEY=<anon/publishable key>
--
-- Without those defines the app runs in offline demo mode (seeded locally).
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

-- Cooperatives / farmers' associations.
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

-- =============================================================================
-- Profiles & auth (1:1 with auth.users)
-- =============================================================================
create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  full_name       text not null,
  role            user_role not null default 'farmer',
  email           text,
  contact_number  text,
  barangay        text,
  cooperative_id  uuid references public.cooperatives(id) on delete set null,
  avatar_url      text,
  created_at      timestamptz not null default now()
);

-- =============================================================================
-- Farm profiling (Phase 1)
-- =============================================================================
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

-- =============================================================================
-- Crop declarations / farming projects (Phase 2) + saturation source
-- =============================================================================
create table if not exists public.crop_declarations (
  id                     uuid primary key default gen_random_uuid(),
  farmer_id              uuid not null references public.profiles(id) on delete cascade,
  farm_id                uuid not null references public.farms(id) on delete cascade,
  crop_id                text not null,            -- references crops.id
  variety                text not null,
  area_ha                numeric not null,
  planting_date          date not null,
  expected_harvest_date  date not null,
  expected_yield_kg      numeric not null,
  barangay               text not null,
  status                 declaration_status not null default 'pending',
  companion_crop_ids     text[] not null default '{}', -- intercropping
  projected_price_per_kg numeric,
  notes                  text,
  reviewer_note          text,                     -- BAW/Technician/MAO feedback
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index if not exists decl_farmer_idx   on public.crop_declarations(farmer_id);
create index if not exists decl_crop_idx      on public.crop_declarations(crop_id);
create index if not exists decl_barangay_idx  on public.crop_declarations(barangay);
create index if not exists decl_status_idx    on public.crop_declarations(status);

-- =============================================================================
-- Economic tracking (Objective 2): expenses + post-harvest production reports
-- =============================================================================
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

-- =============================================================================
-- Digital logbook & incident reporting (Objective 4)
-- =============================================================================
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

-- =============================================================================
-- Supply chain channels (Objective 3) + reference data
-- =============================================================================
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

-- Reference crops (agronomic + economic baselines for the engines).
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

-- Historical/observed market prices.
create table if not exists public.market_prices (
  id            uuid primary key default gen_random_uuid(),
  crop_id       text not null references public.crops(id) on delete cascade,
  price_per_kg  numeric not null,
  recorded_on   date not null,
  market        text
);

-- =============================================================================
-- Row Level Security (RLS)
-- Farmers see only their own rows; cooperatives & MAO get read access to the
-- municipal dataset for supply-chain governance. Tighten as needed.
-- =============================================================================
alter table public.profiles          enable row level security;
alter table public.farms             enable row level security;
alter table public.crop_declarations enable row level security;
alter table public.expenses          enable row level security;
alter table public.production_reports enable row level security;
alter table public.logbook_entries   enable row level security;
alter table public.calamity_reports  enable row level security;
alter table public.market_channels   enable row level security;

-- Helper: current user's role.
create or replace function public.current_role()
returns user_role language sql stable as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Profiles: a user manages their own profile.
drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

-- Farms: owner full access.
drop policy if exists farms_owner on public.farms;
create policy farms_owner on public.farms
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Declarations: farmer owns; cooperative/MAO/technician/baw can read all.
drop policy if exists decl_owner on public.crop_declarations;
create policy decl_owner on public.crop_declarations
  for all using (farmer_id = auth.uid()) with check (farmer_id = auth.uid());

drop policy if exists decl_gov_read on public.crop_declarations;
create policy decl_gov_read on public.crop_declarations
  for select using (public.current_role() in
    ('cooperative','mao','technician','baw'));

-- Expenses / production / logbook: farmer-private.
drop policy if exists expenses_owner on public.expenses;
create policy expenses_owner on public.expenses
  for all using (farmer_id = auth.uid()) with check (farmer_id = auth.uid());

drop policy if exists prod_owner on public.production_reports;
create policy prod_owner on public.production_reports
  for all using (farmer_id = auth.uid()) with check (farmer_id = auth.uid());

drop policy if exists logbook_owner on public.logbook_entries;
create policy logbook_owner on public.logbook_entries
  for all using (farmer_id = auth.uid()) with check (farmer_id = auth.uid());

-- Calamity: farmer owns; MAO can read/verify all.
drop policy if exists calamity_owner on public.calamity_reports;
create policy calamity_owner on public.calamity_reports
  for all using (farmer_id = auth.uid()) with check (farmer_id = auth.uid());

drop policy if exists calamity_mao on public.calamity_reports;
create policy calamity_mao on public.calamity_reports
  for select using (public.current_role() in ('mao','technician','baw'));

-- Market channels: cooperative members manage their cooperative's channels.
drop policy if exists channels_coop on public.market_channels;
create policy channels_coop on public.market_channels
  for all using (
    cooperative_id = (select cooperative_id from public.profiles where id = auth.uid())
  ) with check (
    cooperative_id = (select cooperative_id from public.profiles where id = auth.uid())
  );

-- Reference tables are world-readable to authenticated users.
alter table public.crops          enable row level security;
alter table public.market_prices  enable row level security;
drop policy if exists crops_read on public.crops;
create policy crops_read on public.crops for select using (auth.role() = 'authenticated');
drop policy if exists prices_read on public.market_prices;
create policy prices_read on public.market_prices for select using (auth.role() = 'authenticated');

-- =============================================================================
-- Auto-update updated_at on declarations.
-- =============================================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists decl_touch on public.crop_declarations;
create trigger decl_touch before update on public.crop_declarations
  for each row execute function public.touch_updated_at();

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
