-- =============================================================================
-- AgriSense — database seed (populates all portals)
--
-- Run AFTER schema.sql, in the Supabase SQL editor (runs as a privileged role,
-- so RLS does not block the inserts). Idempotent: safe to re-run.
--
-- Creates working LOGIN accounts (password for all: "AgriSense123!"):
--   mao@agrisense.ph     — MAO administrator (web portal)
--   baw@agrisense.ph     — Barangay Agricultural Worker (web)
--   tech@agrisense.ph    — Agricultural Technician (web)
--   coop@agrisense.ph    — Cooperative / Association (mobile)
--   farmer@agrisense.ph  — Juan Dela Cruz, Farmer (mobile)
--
-- Plus 50 background farmers (no login) so the municipal dataset is realistic:
-- ~42 declare Ampalaya harvesting the SAME week → a genuine High Market
-- Saturation Index and a congested harvest window, exactly the oversupply
-- scenario AgriSense exists to detect.
-- =============================================================================

-- 1) Cooperative (must exist before profiles reference it) ---------------------
insert into public.cooperatives
  (id, name, barangay, contact_person, contact_number, member_count, buy_back_capacity_tons, created_at)
values
  ('c0000000-0000-4000-8000-000000000001',
   'Tubungan Vegetable Growers Association', 'Poblacion',
   'Maria Santos', '0917 555 0142', 58, 120, now() - interval '400 days')
on conflict (id) do nothing;

-- 2) Named login users: auth.users + auth.identities + profiles ----------------
do $$
declare
  pw text := 'AgriSense123!';
  r  record;
begin
  for r in select * from (values
    ('a0000000-0000-4000-8000-000000000001'::uuid,'mao@agrisense.ph','mao','Engr. Roberto Aquino','Poblacion',null::uuid),
    ('a0000000-0000-4000-8000-000000000002'::uuid,'baw@agrisense.ph','baw','Lourdes Gabon','Igpaho',null),
    ('a0000000-0000-4000-8000-000000000003'::uuid,'tech@agrisense.ph','technician','Engr. Felix Donado','Poblacion',null),
    ('a0000000-0000-4000-8000-000000000004'::uuid,'coop@agrisense.ph','cooperative','Maria Santos','Poblacion','c0000000-0000-4000-8000-000000000001'::uuid),
    ('a0000000-0000-4000-8000-000000000005'::uuid,'farmer@agrisense.ph','farmer','Juan Dela Cruz','Igpaho','c0000000-0000-4000-8000-000000000001'::uuid)
  ) as t(id,email,role,full_name,barangay,coop_id)
  loop
    insert into auth.users
      (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
       created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
       confirmation_token,recovery_token,email_change_token_new,email_change)
    values
      ('00000000-0000-0000-0000-000000000000', r.id,'authenticated','authenticated',
       r.email, crypt(pw, gen_salt('bf')), now(), now(), now(),
       '{"provider":"email","providers":["email"]}',
       jsonb_build_object('full_name', r.full_name), false, '', '', '', '')
    on conflict (id) do nothing;

    insert into auth.identities
      (id,user_id,identity_data,provider,provider_id,last_sign_in_at,created_at,updated_at)
    values
      (gen_random_uuid(), r.id,
       jsonb_build_object('sub', r.id::text, 'email', r.email),
       'email', r.id::text, now(), now(), now())
    on conflict do nothing;

    insert into public.profiles
      (id,full_name,role,email,barangay,cooperative_id,contact_number,created_at)
    values
      (r.id, r.full_name, r.role::user_role, r.email, r.barangay, r.coop_id,
       '0918 000 ' || lpad((random()*9999)::int::text,4,'0'), now())
    on conflict (id) do update
      set full_name = excluded.full_name,
          role = excluded.role,
          cooperative_id = excluded.cooperative_id;
  end loop;
end $$;

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

-- 4) Juan's declarations (current approved + pending + last-season harvested) ---
insert into public.crop_declarations
  (id, farmer_id, farm_id, crop_id, variety, area_ha, planting_date,
   expected_harvest_date, expected_yield_kg, barangay, status,
   companion_crop_ids, projected_price_per_kg, notes, created_at, updated_at)
values
  ('a3000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000005','a2000000-0000-4000-8000-000000000005',
   'ampalaya','Galaxy',1.0, current_date - 45, current_date + 25, 12000,'Igpaho',
   'approved','{}',45,'First declaration of the dry season.',
   now() - interval '45 days', now()),
  ('a3000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000005','a2000000-0000-4000-8000-000000000005',
   'eggplant','Casino',0.5, current_date - 10, current_date + 70, 9000,'Igpaho',
   'pending','{string_beans}',40,null, now() - interval '10 days', now()),
  ('a3000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000005','a2000000-0000-4000-8000-000000000005',
   'okra','Smooth Green',0.6, current_date - 90, current_date - 10, 5400,'Igpaho',
   'harvested','{}',35,'Last season project.', now() - interval '95 days', now())
on conflict (id) do nothing;

-- 5) Juan's expense ledger (Objective 2) --------------------------------------
insert into public.expenses
  (id, declaration_id, farmer_id, category, description, amount, incurred_on)
values
  ('e0000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','seed','Galaxy F1 ampalaya seeds (250g)',3500, current_date - 44),
  ('e0000000-0000-4000-8000-000000000002','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','fertilizer','Complete 14-14-14 (4 bags)',6400, current_date - 40),
  ('e0000000-0000-4000-8000-000000000003','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','labor','Land prep & trellising (8 man-days)',4000, current_date - 38),
  ('e0000000-0000-4000-8000-000000000004','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','irrigation','Pump fuel & water fees',1800, current_date - 20),
  ('e0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','pesticide','Foliar & pest management',2100, current_date - 12),
  ('e0000000-0000-4000-8000-000000000006','a3000000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','seed','Okra seeds',1800, current_date - 90),
  ('e0000000-0000-4000-8000-000000000007','a3000000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','fertilizer','Urea + complete',5200, current_date - 80),
  ('e0000000-0000-4000-8000-000000000008','a3000000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','labor','Weeding & harvest labor',9000, current_date - 30)
on conflict (id) do nothing;

-- 6) Post-harvest production report for the okra project (realized P&L) ---------
insert into public.production_reports
  (id, declaration_id, farmer_id, actual_yield_kg, actual_price_per_kg,
   harvested_on, loss_kg, notes)
values
  ('a4000000-0000-4000-8000-000000000003','a3000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000005', 5200, 38, current_date - 10, 200,
   'Good season; minor rejects from fruit borer.')
on conflict (id) do nothing;

-- 7) Juan's agronomic logbook (Objective 4) -----------------------------------
insert into public.logbook_entries
  (id, farmer_id, declaration_id, activity, title, performed_on, details, input_used, quantity, unit, cost)
values
  ('109b0000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','land_prep','Plowing and bed preparation', current_date - 44,'Two passes, raised beds at 1m spacing.',null,null,null,null),
  ('109b0000-0000-4000-8000-000000000002','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','planting','Direct seeding of ampalaya', current_date - 40,null,'Galaxy F1',250,'g',null),
  ('109b0000-0000-4000-8000-000000000003','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','fertilizing','Basal fertilizer application', current_date - 38,null,'Complete 14-14-14',200,'kg',6400),
  ('109b0000-0000-4000-8000-000000000004','a0000000-0000-4000-8000-000000000005','a3000000-0000-4000-8000-000000000001','pest_control','Foliar spray vs. fruit fly', current_date - 12,null,'Cypermethrin',1,'L',2100)
on conflict (id) do nothing;

-- 8) Juan's calamity report (Objective 4) — under MAO review -------------------
insert into public.calamity_reports
  (id, farmer_id, declaration_id, crop_id, barangay, type, occurred_on,
   affected_area_ha, loss_percent, estimated_loss_value, status, description)
values
  ('ca100000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000005',
   'a3000000-0000-4000-8000-000000000001','ampalaya','Igpaho','typhoon',
   current_date - 8, 0.4, 35, 18000, 'under_review',
   'Strong winds from TS "Crising" lodged trellises on the lower plot.')
on conflict (id) do nothing;

-- 9) Validation audit trail for Juan's approved ampalaya (web portal) ----------
insert into public.declaration_reviews
  (id, declaration_id, reviewer_id, reviewer_role, from_status, to_status, note, created_at)
values
  ('4e100000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000002','baw','pending','baw_approved','Farm photos and area verified.', now() - interval '30 days'),
  ('4e100000-0000-4000-8000-000000000002','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000003','technician','baw_approved','technician_verified','Yield estimate realistic for the location.', now() - interval '25 days'),
  ('4e100000-0000-4000-8000-000000000003','a3000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','mao','technician_verified','approved','Approved for municipal records.', now() - interval '20 days')
on conflict (id) do nothing;

-- 10) Cooperative buy-back / alternative market channels (Objective 3) ----------
insert into public.market_channels
  (id, cooperative_id, name, type, capacity_tons, crop_ids, price_per_kg, contact, notes)
values
  ('c4a00000-0000-4000-8000-000000000001','c0000000-0000-4000-8000-000000000001','Association Surplus Buy-back','buy_back',60,'{ampalaya,eggplant,okra}',38,'0917 555 0142','Guaranteed floor price for member surplus.'),
  ('c4a00000-0000-4000-8000-000000000002','c0000000-0000-4000-8000-000000000001','Iloilo City Terminal Market','neighboring_market',200,'{ampalaya,tomato,squash}',42,'La Paz Public Market consolidators',null),
  ('c4a00000-0000-4000-8000-000000000003','c0000000-0000-4000-8000-000000000001','AgriProcess Pickling Plant','processor',80,'{ampalaya,squash}',30,'procurement@agriprocess.ph','Absorbs Grade-B produce for pickling.')
on conflict (id) do nothing;

-- 11) 50 background farmers + farms + declarations (municipal realism) ----------
-- ~42 declare Ampalaya harvesting the same week → High saturation + congestion.
do $$
declare
  pw     text := 'AgriSense123!';
  coop   uuid := 'c0000000-0000-4000-8000-000000000001';
  fnames text[] := array['Jose','Maria','Antonio','Rosa','Pedro','Ana','Mario','Linda','Carlos','Elena','Ramon','Teresa','Andres','Carmen','Felipe','Lucia'];
  lnames text[] := array['Reyes','Santos','Cruz','Bautista','Garcia','Ramos','Mendoza','Flores','Villanueva','Castro','Aquino','Gabon','Donado','Salcedo'];
  brgys  text[] := array['Igpaho','Bading','Bagunanay','Bondoc','Buenavista','Cabunga','Igcabugao','Igtuble','Molina','Morubuan','Poblacion','Tabat','Talenton','Teniente Loling'];
  i      int;
  uid    uuid;
  fid    uuid;
  cropid text;
  ar     numeric;
  st     declaration_status;
  hv     date;
  fname  text;
  brgy   text;
  growth int;
  byield numeric;
  bprice numeric;
begin
  for i in 1..50 loop
    uid  := ('b1000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;
    fid  := ('b2000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;
    fname := fnames[1 + (i % array_length(fnames,1))] || ' ' ||
             lnames[1 + (i % array_length(lnames,1))];
    brgy := brgys[1 + (i % array_length(brgys,1))];

    insert into auth.users
      (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
       created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
       confirmation_token,recovery_token,email_change_token_new,email_change)
    values
      ('00000000-0000-0000-0000-000000000000', uid,'authenticated','authenticated',
       'bg'||i||'@agrisense.local', crypt(pw, gen_salt('bf')), now(), now(), now(),
       '{"provider":"email","providers":["email"]}',
       jsonb_build_object('full_name', fname), false, '', '', '', '')
    on conflict (id) do nothing;

    insert into public.profiles
      (id,full_name,role,email,barangay,cooperative_id,created_at)
    values (uid, fname, 'farmer', 'bg'||i||'@agrisense.local', brgy, coop, now())
    on conflict (id) do nothing;

    insert into public.farms
      (id,owner_id,name,barangay,total_area_ha,soil_type,created_at)
    values (fid, uid, fname || ' Farm', brgy, 1.5, 'Clay loam', now())
    on conflict (id) do nothing;

    if i <= 42 then
      cropid := 'ampalaya';
      ar := 1.0 + (i % 7) * 0.1;        -- 1.0 .. 1.6 ha
      hv := current_date + 25;           -- same week → congestion + oversupply
    else
      cropid := (array['eggplant','okra','tomato','squash','string_beans','corn','pechay','eggplant'])[1 + ((i-43) % 8)];
      ar := 0.8 + (i % 5) * 0.1;
      hv := current_date + 30 + (i % 20);
    end if;
    st := case when i % 9 = 0 then 'pending'::declaration_status
               else 'approved'::declaration_status end;

    select growth_duration_days, baseline_yield_per_ha, baseline_price_per_kg
      into growth, byield, bprice from public.crops where id = cropid;

    insert into public.crop_declarations
      (id, farmer_id, farm_id, crop_id, variety, area_ha, planting_date,
       expected_harvest_date, expected_yield_kg, barangay, status,
       projected_price_per_kg, created_at, updated_at)
    values
      (('b3000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid, uid, fid, cropid,
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
-- Seasonal index lifts wet/lean months and dips at the dry harvest glut, with a
-- ~4%/yr trend. Deterministic; re-runnable via the delete below.
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
set member_count = (select count(*) from public.profiles p
                    where p.cooperative_id = c.id and p.role = 'farmer')
where c.id = 'c0000000-0000-4000-8000-000000000001';

-- =============================================================================
-- Done. Sign in on mobile as farmer@agrisense.ph or coop@agrisense.ph, and on
-- the web portal as mao@agrisense.ph / baw@agrisense.ph / tech@agrisense.ph.
-- Password for all: AgriSense123!
-- =============================================================================
