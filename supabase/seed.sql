-- =============================================================================
-- AgriSense — database seed (populates all portals)
--
-- Run AFTER schema.sql in the Supabase SQL editor. Idempotent: safe to re-run.
--
-- Uses CUSTOM AUTH (no Supabase Auth / auth.users). Login accounts are plain
-- rows in public.profiles with password stored as plain text.
--
-- Login accounts (password: AgriSense123!):
--   mao@agrisense.ph     — MAO administrator  (web portal)
--   baw@agrisense.ph     — Barangay Agri Worker (web)
--   tech@agrisense.ph    — Agri Technician (web)
--   coop@agrisense.ph    — Cooperative (mobile)
--   farmer@agrisense.ph  — Juan Dela Cruz, Farmer (mobile)
--
-- Plus 48 association members sized to a real upland vegetable association:
-- smallholder plots of 0.3-0.9 ha, ~30 ha planted across 8 crops. Ampalaya is
-- the cash crop and is over-planted (18 growers clustering into a five-week
-- harvest band) → High Market Saturation Index and a congested window, which is
-- the oversupply scenario AgriSense exists to detect. Eggplant sits near
-- balance; the remaining crops have headroom.
-- =============================================================================

-- 1) Cooperative (must exist before profiles reference it) ---------------------
insert into public.cooperatives
  (id, name, barangay, contact_person, contact_number, member_count, buy_back_capacity_tons, created_at)
values
  ('c0000000-0000-4000-8000-000000000001',
   'Tubungan Vegetable Growers Association', 'Zone I (Poblacion)',
   'Maria Santos', '0917 555 0142', 49, 120, now() - interval '400 days')
on conflict (id) do nothing;

-- 2) Named login accounts (plain text password) --------------------------------
insert into public.profiles
  (id, email, password, first_name, middle_name, last_name, username, role,
   barangay, cooperative_id, contact_number, rsbsa_number, verification,
   verified_at, created_at)
values
  ('a0000000-0000-4000-8000-000000000001',
   'mao@agrisense.ph', 'AgriSense123!', 'Roberto', null, 'Aquino',
   'roberto.aquino', 'mao', 'Zone I (Poblacion)', null,
   '0917 555 0001', null, 'verified',
   now() - interval '400 days', now() - interval '400 days'),

  ('a0000000-0000-4000-8000-000000000002',
   'baw@agrisense.ph', 'AgriSense123!', 'Lourdes', null, 'Gabon',
   'lourdes.gabon', 'baw', 'Igpaho', null,
   '0918 555 0002', null, 'verified',
   now() - interval '400 days', now() - interval '400 days'),

  ('a0000000-0000-4000-8000-000000000003',
   'tech@agrisense.ph', 'AgriSense123!', 'Felix', null, 'Donado',
   'felix.donado', 'technician', 'Zone I (Poblacion)', null,
   '0917 555 0003', null, 'verified',
   now() - interval '400 days', now() - interval '400 days'),

  ('a0000000-0000-4000-8000-000000000004',
   'coop@agrisense.ph', 'AgriSense123!', 'Maria', 'Luisa', 'Santos',
   'maria.santos', 'cooperative', 'Zone I (Poblacion)',
   'c0000000-0000-4000-8000-000000000001',
   '0917 555 0142', null, 'verified',
   now() - interval '400 days', now() - interval '400 days'),

  ('a0000000-0000-4000-8000-000000000005',
   'farmer@agrisense.ph', 'AgriSense123!', 'Juan', 'Ramos', 'Dela Cruz',
   'juan.delacruz', 'farmer', 'Igpaho',
   'c0000000-0000-4000-8000-000000000001',
   '0918 555 0005', '06-30-79-001-000123', 'verified',
   now() - interval '118 days', now() - interval '120 days')
on conflict (id) do update
  set first_name     = excluded.first_name,
      last_name      = excluded.last_name,
      username       = excluded.username,
      role           = excluded.role,
      cooperative_id = excluded.cooperative_id,
      rsbsa_number   = excluded.rsbsa_number,
      verification   = excluded.verification,
      password       = excluded.password;

-- 3) Juan's farm (Phase 1) -----------------------------------------------------
insert into public.farms
  (id, owner_id, name, barangay, total_area_ha, latitude, longitude, soil_type,
   previous_crops, previous_activities, created_at)
values
  ('a2000000-0000-4000-8000-000000000005',
   'a0000000-0000-4000-8000-000000000005',
   'Dela Cruz Family Farm', 'Igpaho', 1.5, 10.7896, 122.3186, 'Clay loam',
   '{ampalaya,eggplant}',
   'Rice paddy (wet season), vegetables (dry season).',
   now() - interval '120 days')
on conflict (id) do nothing;

-- 4) Juan's declarations (two standing + one harvested last season) -------------
insert into public.crop_declarations
  (id, farmer_id, farm_id, crop_id, variety, area_ha, planting_date,
   expected_harvest_date, expected_yield_kg, barangay, status,
   companion_crop_ids, projected_price_per_kg, notes, created_at, updated_at)
values
  ('a3000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000005',
   'ampalaya', 'Galaxy', 1.0, current_date - 45, current_date + 25, 12000, 'Igpaho',
   'active', '{}', 45, 'First declaration of the dry season.',
   now() - interval '45 days', now()),

  ('a3000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000005',
   'eggplant', 'Casino', 0.5, current_date - 10, current_date + 70, 9000, 'Igpaho',
   'active', '{string_beans}', 40, null,
   now() - interval '10 days', now()),

  ('a3000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000005',
   'okra', 'Smooth Green', 0.6, current_date - 90, current_date - 10, 5400, 'Igpaho',
   'harvested', '{}', 35, 'Last season project.',
   now() - interval '95 days', now())
on conflict (id) do nothing;

-- 5) Juan's expense ledger (Objective 2) --------------------------------------
insert into public.expenses
  (id, declaration_id, farmer_id, category, description, amount, incurred_on)
values
  ('e0000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','seed','Galaxy F1 ampalaya seeds (250g)',3500,current_date - 44),
  ('e0000000-0000-4000-8000-000000000002','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','fertilizer','Complete 14-14-14 (4 bags)',6400,current_date - 40),
  ('e0000000-0000-4000-8000-000000000003','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','labor','Land prep & trellising (8 man-days)',4000,current_date - 38),
  ('e0000000-0000-4000-8000-000000000004','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','irrigation','Pump fuel & water fees',1800,current_date - 20),
  ('e0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','pesticide','Foliar & pest management',2100,current_date - 12),
  ('e0000000-0000-4000-8000-000000000006','a3000000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','seed','Okra seeds',1800,current_date - 90),
  ('e0000000-0000-4000-8000-000000000007','a3000000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','fertilizer','Urea + complete',5200,current_date - 80),
  ('e0000000-0000-4000-8000-000000000008','a3000000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','labor','Weeding & harvest labor',9000,current_date - 30)
on conflict (id) do nothing;

-- 6) Post-harvest production report for the okra project (realized P&L) ---------
insert into public.production_reports
  (id, declaration_id, farmer_id, actual_yield_kg, actual_price_per_kg,
   harvested_on, loss_kg, notes)
values
  ('a4000000-0000-4000-8000-000000000003',
   'a3000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000005',
   5200, 38, current_date - 10, 200,
   'Good season; minor rejects from fruit borer.')
on conflict (id) do nothing;

-- 7) Juan's agronomic logbook (Objective 4) -----------------------------------
insert into public.logbook_entries
  (id, farmer_id, declaration_id, activity, title, performed_on, details, input_used, quantity, unit, cost)
values
  ('109b0000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','land_prep','Plowing and bed preparation',current_date - 44,'Two passes, raised beds at 1m spacing.',null,null,null,null),
  ('109b0000-0000-4000-8000-000000000002','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','planting','Direct seeding of ampalaya',current_date - 40,null,'Galaxy F1',250,'g',null),
  ('109b0000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','fertilizing','Basal fertilizer application',current_date - 38,null,'Complete 14-14-14',200,'kg',6400),
  ('109b0000-0000-4000-8000-000000000004','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','pest_control','Foliar spray vs. fruit fly',current_date - 12,null,'Cypermethrin',1,'L',2100)
on conflict (id) do nothing;

-- 7b) Pair the two costs that belong to a logged activity ----------------------
-- The ₱6,400 fertilizer and the ₱2,100 spray appear in both the ledger and the
-- logbook because they are the *same* cost. Left unlinked they read as four
-- separate outlays; linked, the app shows two, entered once. (The link is set
-- here rather than inline because expenses are inserted before logbook_entries.)
update public.expenses e
   set logbook_entry_id = v.log_id,
       description      = v.description,
       incurred_on      = v.incurred_on
  from (values
    ('e0000000-0000-4000-8000-000000000002'::uuid,
     '109b0000-0000-4000-8000-000000000003'::uuid,
     'Basal fertilizer application', current_date - 38),
    ('e0000000-0000-4000-8000-000000000005'::uuid,
     '109b0000-0000-4000-8000-000000000004'::uuid,
     'Foliar spray vs. fruit fly', current_date - 12)
  ) as v(expense_id, log_id, description, incurred_on)
 where e.id = v.expense_id;

update public.logbook_entries l
   set expense_id = v.expense_id
  from (values
    ('109b0000-0000-4000-8000-000000000003'::uuid,
     'e0000000-0000-4000-8000-000000000002'::uuid),
    ('109b0000-0000-4000-8000-000000000004'::uuid,
     'e0000000-0000-4000-8000-000000000005'::uuid)
  ) as v(log_id, expense_id)
 where l.id = v.log_id;

-- 8) Juan's calamity report (Objective 4) — under MAO review -------------------
insert into public.calamity_reports
  (id, farmer_id, declaration_id, crop_id, barangay, type, occurred_on,
   affected_area_ha, loss_percent, estimated_loss_value, status, description)
values
  ('ca100000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000005',
   'a3000000-0000-4000-8000-000000000001',
   'ampalaya', 'Igpaho', 'typhoon', current_date - 8,
   0.4, 35, 18000, 'under_review',
   'Strong winds from TS "Crising" lodged trellises on the lower plot.')
on conflict (id) do nothing;

-- 9) (retired) Validation audit trail ------------------------------------------
-- The BAW -> Technician -> MAO validation chain was retired, so no review
-- rows are seeded. public.declaration_reviews is kept only for history.

-- 10) Cooperative buy-back / alternative market channels (Objective 3) ----------
insert into public.market_channels
  (id, cooperative_id, name, type, capacity_tons, crop_ids, price_per_kg, contact, notes)
values
  ('c4a00000-0000-4000-8000-000000000001','c0000000-0000-4000-8000-000000000001','Association Surplus Buy-back','buy_back',60,'{ampalaya,eggplant,okra}',38,'0917 555 0142','Guaranteed floor price for member surplus.'),
  ('c4a00000-0000-4000-8000-000000000002','c0000000-0000-4000-8000-000000000001','Iloilo City Terminal Market','neighboring_market',200,'{ampalaya,tomato,squash}',42,'La Paz Public Market consolidators',null),
  ('c4a00000-0000-4000-8000-000000000003','c0000000-0000-4000-8000-000000000001','AgriProcess Pickling Plant','processor',80,'{ampalaya,squash}',30,'procurement@agriprocess.ph','Absorbs Grade-B produce for pickling.')
on conflict (id) do nothing;

-- 11) 48 association members + farms + declarations (municipal realism) ---------
-- Sized to a real upland vegetable association: smallholder plots of
-- 0.3-0.9 ha, ~30 ha planted in total. Ampalaya is the cash crop and is
-- over-planted (18 growers, harvests clustered across five weeks), which is
-- the coordination failure AgriSense exists to surface. Eggplant sits near
-- balance; everything else has headroom.
do $$
declare
  coop   uuid := 'c0000000-0000-4000-8000-000000000001';
  fnames text[] := array['Jose','Maria','Antonio','Rosa','Pedro','Ana','Mario','Linda','Carlos','Elena','Ramon','Teresa','Andres','Carmen','Felipe','Lucia'];
  lnames text[] := array['Reyes','Santos','Cruz','Bautista','Garcia','Ramos','Mendoza','Flores','Villanueva','Castro','Aquino','Gabon','Donado','Salcedo'];
  brgys  text[] := array['Igpaho','Badiang','Bagunanay','Bondoc','Buenavista','Cadabdab','Igdampog Sur','Igtuble','Molina','Morcillas','Zone I (Poblacion)','Tabat','Talento','Teniente Benito'];
  i      int;
  uid    uuid;
  fid    uuid;
  cropid text;
  ar     numeric;
  st     declaration_status;
  hv     date;
  brgy   text;
  growth int;
  byield numeric;
  bprice numeric;
begin
  for i in 1..48 loop
    uid   := ('b1000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;
    fid   := ('b2000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;
    brgy  := brgys[1 + (i % array_length(brgys,1))];

    insert into public.profiles
      (id, email, password, first_name, last_name, username, role,
       barangay, cooperative_id, verification, created_at)
    values
      (uid, 'bg'||i||'@agrisense.local', 'AgriSense123!',
       fnames[1 + (i % array_length(fnames,1))],
       lnames[1 + (i % array_length(lnames,1))],
       'farmer'||i,
       'farmer', brgy, coop, 'verified', now())
    on conflict (id) do nothing;

    insert into public.farms
      (id, owner_id, barangay, total_area_ha, soil_type, created_at)
    values
      (fid, uid, brgy, round((0.6 + (i % 9) * 0.15)::numeric, 2),
       (array['Clay loam','Loam','Sandy loam'])[1 + (i % 3)], now())
    on conflict (id) do nothing;

    -- Crop mix and plot sizes reflect what smallholders in an upland
    -- vegetable association actually plant. Harvest dates are spread, but
    -- the ampalaya growers cluster into a five-week band — a real glut,
    -- not every farmer picking on the same day.
    if i <= 18 then
      cropid := 'ampalaya';
      ar     := 0.55 + (i % 6) * 0.07;      -- 0.55 - 0.90 ha
      hv     := current_date + 20 + (i % 35);
    elsif i <= 31 then
      cropid := 'eggplant';
      ar     := 0.45 + (i % 5) * 0.06;      -- 0.45 - 0.69 ha
      hv     := current_date + 25 + (i % 55);
    elsif i <= 36 then
      cropid := 'okra';
      ar     := 0.35 + (i % 4) * 0.07;
      hv     := current_date + 30 + (i % 70);
    elsif i <= 40 then
      cropid := 'string_beans';
      ar     := 0.40 + (i % 3) * 0.08;
      hv     := current_date + 35 + (i % 75);
    elsif i <= 43 then
      cropid := 'tomato';
      ar     := 0.30 + (i % 3) * 0.08;
      hv     := current_date + 40 + (i % 80);
    elsif i <= 46 then
      cropid := 'squash';
      ar     := 0.50 + (i % 3) * 0.08;
      hv     := current_date + 45 + (i % 85);
    elsif i = 47 then
      cropid := 'corn';
      ar     := 0.80;
      hv     := current_date + 60;
    else
      cropid := 'pechay';
      ar     := 0.30;
      hv     := current_date + 22;
    end if;
    ar := round(ar::numeric, 2);

    -- Declarations are records, not applications: every standing crop is
    -- simply active.
    st := 'active'::declaration_status;

    select growth_duration_days, baseline_yield_per_ha, baseline_price_per_kg
      into growth, byield, bprice from public.crops where id = cropid;

    insert into public.crop_declarations
      (id, farmer_id, farm_id, crop_id, variety, area_ha, planting_date,
       expected_harvest_date, expected_yield_kg, barangay, status,
       projected_price_per_kg, created_at, updated_at)
    values
      (('b3000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
       uid, fid, cropid,
       initcap(replace(cropid,'_',' ')) || ' local', ar,
       hv - growth, hv, round(ar * byield), brgy, st, bprice,
       now() - interval '40 days', now())
    on conflict (id) do nothing;
  end loop;
end $$;

-- 12) Demand baselines (saturation denominator; web reference data) -------------
insert into public.demand_baselines (crop_id, annual_demand_tons) values
  ('ampalaya',500),('eggplant',620),('okra',410),('string_beans',360),
  ('tomato',540),('corn',700),('squash',480),('pechay',300)
on conflict (crop_id) do update set annual_demand_tons = excluded.annual_demand_tons;

-- 13) 36-month farmgate price history (calibration; Objectives 1 & 2) -----------
delete from public.market_prices where market = 'Tubungan farmgate';
insert into public.market_prices (crop_id, price_per_kg, recorded_on, market)
select c.crop_id,
       round((c.base * (1 + 0.04 * (yr - 2023)) *
              (1 + c.amp * ((array[1.00,0.90,0.85,0.88,0.98,1.05,1.15,1.20,1.18,1.10,1.02,1.05])[mo] - 1))
             )::numeric, 2),
       make_date(yr, mo, 1),
       'Tubungan farmgate'
from (values
  ('ampalaya', 42::numeric, 1.0::numeric),
  ('eggplant', 38, 0.9),
  ('okra', 35, 0.9),
  ('string_beans', 50, 1.0),
  ('tomato', 32, 1.5),
  ('corn', 22, 0.6),
  ('squash', 24, 0.7),
  ('pechay', 30, 1.2)
) as c(crop_id, base, amp)
cross join generate_series(2023, 2025) as yr
cross join generate_series(1, 12) as mo;

-- 14) Keep cooperative member_count in sync with seeded members ----------------
update public.cooperatives c
set member_count = (
  select count(*) from public.profiles p
  where p.cooperative_id = c.id and p.role = 'farmer'
)
where c.id = 'c0000000-0000-4000-8000-000000000001';


-- 15) Cooperative demand commitments (saturation denominator) -------------------
-- Demand declared by a cooperative takes precedence over the municipal monthly
-- baseline, so the oversupply warnings farmers see rest on a figure someone is
-- accountable for rather than a hardcoded constant.
insert into public.demand_signals
  (id, cooperative_id, crop_id, period_start, period_end, demand_tons,
   buyer_type, price_per_kg, buyer_name, notes, created_at)
values
  ('d1000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001', 'ampalaya',
   current_date - 15, current_date + 45, 34, 'bagsakan', 40,
   'Tubungan Bagsakan', 'Weekly consolidation every Tuesday and Friday.', now()),
  ('d1000000-0000-4000-8000-000000000002',
   'c0000000-0000-4000-8000-000000000001', 'eggplant',
   current_date - 10, current_date + 50, 52, 'institutional', 44,
   'DepEd school feeding programme', null, now()),
  ('d1000000-0000-4000-8000-000000000003',
   'c0000000-0000-4000-8000-000000000001', 'pechay',
   current_date - 5, current_date + 25, 18, 'retail', 35,
   'Iloilo City retailers', null, now())
on conflict (id) do nothing;

-- 16) Barangay technician coverage ---------------------------------------------
-- With no approval chain, the technician is an advisory contact rather than a
-- gatekeeper; the farmer dashboard shows who covers their barangay.
insert into public.barangay_assignments
  (id, barangay, technician_id, role, technician_name, contact_number, assigned_at)
values
  ('d2000000-0000-4000-8000-000000000001', 'Igpaho',
   'a0000000-0000-4000-8000-000000000003', 'technician',
   'Engr. Felix Donado', '0917 555 0003', now() - interval '200 days'),
  ('d2000000-0000-4000-8000-000000000002', 'Zone I (Poblacion)',
   'a0000000-0000-4000-8000-000000000003', 'technician',
   'Engr. Felix Donado', '0917 555 0003', now() - interval '200 days'),
  ('d2000000-0000-4000-8000-000000000003', 'Igpaho',
   'a0000000-0000-4000-8000-000000000002', 'baw',
   'Lourdes Gabon', '0918 555 0002', now() - interval '200 days')
on conflict (barangay, technician_id) do nothing;

-- 17) Crop calendar for Juan's standing ampalaya --------------------------------
-- The crop's agronomic protocol expanded against its real planting date. The
-- app regenerates this whenever a declaration is saved; seeding a slice of it
-- means the calendar and the "needs doing now" card are populated on first run.
insert into public.planned_activities
  (id, declaration_id, farmer_id, activity, title, scheduled_on,
   days_after_planting, suggested_input, suggested_qty_per_ha, unit, status,
   completed_on, created_at)
select
  ('d3000000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid,
  'a3000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000005',
  v.activity::activity_type, v.title,
  current_date + v.offset_days, v.dap, v.input, v.qty, v.unit,
  v.status::planned_activity_status,
  case when v.status = 'done' then current_date + v.offset_days end,
  now()
from (values
  (1, 'land_prep',   'Plow and first harrow',        -54, -14, null,  null, null, 'done'),
  (2, 'fertilizing', 'Apply basal fertilizer',       -40,   0,
      'Complete 14-14-14 + compost', 4.0, 'bags', 'done'),
  (3, 'weeding',     'First weeding / off-barring',  -26,  14, null,  null, null, 'done'),
  (4, 'pest_control','Scheduled protective spray',    -3,  37,
      'Cypermethrin / fungicide rotation', 0.5, 'L', 'pending'),
  (5, 'irrigation',  'Irrigate',                       1,  41, null,  null, null, 'pending'),
  (6, 'fertilizing', 'Flowering-stage fertilizer',     4,  44,
      'Urea 46-0-0', 1.0, 'bags', 'pending'),
  (7, 'harvesting',  'Harvest - pick 1',              12,  70, null,  null, null, 'pending')
) as v(n, activity, title, offset_days, dap, input, qty, unit, status)
on conflict (id) do nothing;


-- 18) Completed previous season — the supply chain ------------------------------
-- The current declarations are all still standing, so nothing had been sold and
-- the MAO's supply-chain dashboard had a single record to draw. This backfills a
-- finished cycle: 34 harvests across eight crops, each with the channel it
-- actually went to.
--
-- The distribution is the point. Roughly 40% reaches the bagsakan (the channel
-- the municipality can see), while traders buying at the farmgate and buyers
-- from neighbouring towns take about 30% straight out of the monitored chain.
-- That gap is the "diin nagkadto ang supply?" the dashboard exists to answer —
-- and the prices show why it happens: a viajero pays ~18% below the bagsakan but
-- collects at the farm, while hauling to the city market earns ~18% more.
do $$
declare
  i         int;
  uid       uuid;
  fid       uuid;
  did       uuid;
  cropid    text;
  ar        numeric;
  brgy      text;
  growth    int;
  byield    numeric;
  bprice    numeric;
  hv        date;
  yieldkg   numeric;
  loss      numeric;
  chan      text;
  buyer     text;
  price     numeric;
  slot      int;
  -- 20-slot cycle: 8 bagsakan, 4 trader, 3 cooperative, 2 direct market,
  -- 2 neighbouring municipality, 1 own consumption.
  channels  text[] := array[
    'bagsakan','trader','bagsakan','cooperative','bagsakan','direct_market',
    'bagsakan','trader','cooperative','bagsakan','neighbouring_municipality',
    'bagsakan','trader','cooperative','bagsakan','direct_market','trader',
    'bagsakan','neighbouring_municipality','own_consumption'];
  traders   text[] := array['Viajero — Guimbal','Viajero — Tigbauan',
                            'Farmgate consolidator (Oton)'];
  outsiders text[] := array['Miagao consolidator','Igbaras buyer',
                            'San Joaquin trader'];
begin
  for i in 1..34 loop
    uid := ('b1000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;
    fid := ('b2000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;
    did := ('b4000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;

    select barangay into brgy from public.farms where id = fid;
    if brgy is null then continue; end if;   -- farm not seeded; skip

    -- Last season's crop mix. Rotation means it is not the same shape as what
    -- is standing now — the ampalaya rush is a *current* phenomenon.
    if    i <= 10 then cropid := 'ampalaya';
    elsif i <= 18 then cropid := 'eggplant';
    elsif i <= 23 then cropid := 'okra';
    elsif i <= 27 then cropid := 'string_beans';
    elsif i <= 30 then cropid := 'tomato';
    elsif i <= 32 then cropid := 'squash';
    elsif i =  33 then cropid := 'pechay';
    else               cropid := 'corn';
    end if;

    ar := round((0.35 + (i % 6) * 0.10)::numeric, 2);   -- 0.35 - 0.85 ha
    hv := current_date - (20 + i * 2)::int;             -- 22 - 88 days ago

    select growth_duration_days, baseline_yield_per_ha, baseline_price_per_kg
      into growth, byield, bprice from public.crops where id = cropid;

    -- Real harvests land under the agronomic mean more often than over it.
    yieldkg := round(ar * byield * (0.85 + (i % 5) * 0.05));
    loss    := round(yieldkg * (0.01 + (i % 4) * 0.01));

    slot  := 1 + (i % array_length(channels,1));
    chan  := channels[slot];

    -- Price follows the channel, which is what makes the routing a real choice
    -- rather than an arbitrary label.
    if chan = 'bagsakan' then
      price := round(bprice, 2);
      buyer := 'Tubungan Bagsakan';
    elsif chan = 'cooperative' then
      price := round(bprice * 1.05, 2);
      buyer := 'TVGA Buy-back Program';
    elsif chan = 'trader' then
      price := round(bprice * 0.82, 2);
      buyer := traders[1 + (i % array_length(traders,1))];
    elsif chan = 'direct_market' then
      price := round(bprice * 1.18, 2);
      buyer := 'La Paz Terminal Market';
    elsif chan = 'neighbouring_municipality' then
      price := round(bprice * 1.10, 2);
      buyer := outsiders[1 + (i % array_length(outsiders,1))];
    else
      price := round(bprice, 2);   -- imputed value; not actually sold
      buyer := null;
    end if;

    insert into public.crop_declarations
      (id, farmer_id, farm_id, crop_id, variety, area_ha, planting_date,
       expected_harvest_date, expected_yield_kg, barangay, status,
       projected_price_per_kg, notes, created_at, updated_at)
    values
      (did, uid, fid, cropid,
       initcap(replace(cropid,'_',' ')) || ' local', ar,
       hv - growth, hv, round(ar * byield), brgy, 'harvested',
       bprice, 'Previous cycle.',
       (hv - growth)::timestamptz, hv::timestamptz)
    on conflict (id) do nothing;

    insert into public.production_reports
      (id, declaration_id, farmer_id, actual_yield_kg, actual_price_per_kg,
       harvested_on, loss_kg, sold_to_channel, buyer_name, created_at)
    values
      (('b5000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
       did, uid, yieldkg, price, hv, loss,
       chan::sales_channel, buyer, hv::timestamptz)
    on conflict (id) do nothing;
  end loop;
end $$;

-- Juan's own okra harvest went to the cooperative rather than the bagsakan.
update public.production_reports
   set sold_to_channel = 'cooperative',
       buyer_name      = 'TVGA Buy-back Program'
 where id = 'a4000000-0000-4000-8000-000000000003';

-- =============================================================================
-- Done. Sign in with:
--   farmer@agrisense.ph / AgriSense123!   (Farmer mobile portal)
--   coop@agrisense.ph   / AgriSense123!   (Cooperative mobile portal)
--   mao@agrisense.ph    / AgriSense123!   (MAO web portal)
-- =============================================================================
