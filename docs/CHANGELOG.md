# AgriSense Mobile — Feature Changelog

Everything built and changed in response to the two adviser consultations, plus
the defects found along the way.

Each entry cites the note that prompted it — `1.4` is batch 1 note 4, `2.9` is
batch 2 note 9 — so any item can be traced back to what was actually asked.
Triage and scope live in [ADVISER_FEEDBACK_MOBILE_SCOPE.md](ADVISER_FEEDBACK_MOBILE_SCOPE.md);
the maths behind the engines lives in [ANALYTICS_AND_MODELLING.md](ANALYTICS_AND_MODELLING.md).

**Status:** `flutter analyze` clean · 38 tests passing · web build succeeds.
Two decisions still need sir's confirmation (see [Decisions](#decisions-awaiting-confirmation))
and the barangay suitability map ships as **synthetic** data.

---

## 1. New features

### 1.1 Crop calendar — the protocol, dated *(note 2.9)*

The logbook only ever recorded the past. The app already knows the crop and the
planting date, so it can now say *when to fertilise, irrigate, and spray*
instead of waiting to be told after the fact.

- `CropCalendarEngine` expands each crop's agronomic protocol against the real
  planting date into dated `PlannedActivity` rows — generated automatically the
  moment a crop is declared.
- Month grid with a dot per scheduled day, plus a 14-day agenda; overdue work is
  surfaced first.
- Each item shows the recommended input and a quantity **scaled to that
  farmer's parcel**, not a per-hectare rate they have to convert.
- `I did this` opens the log form pre-filled; `Skip` dismisses work that is no
  longer needed.
- Editing a planting date reschedules pending work only — completed and skipped
  items keep their original dates. History is never rewritten under the farmer.

New: `lib/core/logic/crop_calendar_engine.dart`, `lib/features/farmer/crop_calendar_screen.dart`,
`lib/models/planned_activity.dart`

### 1.2 One entry for an activity and what it cost *(note 1.4)*

Logging work and recording its cost were two separate forms, and a cost typed
into the logbook **never reached the P&L at all** — see [§3.1](#31-logbook-costs-never-reached-the-pl).

- A collapsed `+ Add cost incurred` control expands inline; the expense category
  is pre-selected from the activity type, so the usual case is "type the amount
  and save".
- One save writes both records, linked in both directions, with rollback if
  either write fails.
- A cost requires a linked crop — an unattributed expense reaches no P&L — and
  says so rather than dropping it silently.
- Deleting either side cleans up the other instead of orphaning it.

### 1.3 Land suitability by barangay *(notes 1.5, 2.10)*

Barangay was captured on every profile, farm, and declaration and read by **no
engine** — every farmer in Tubungan saw an identical crop ranking.

- `SuitabilityEngine` scores each crop per barangay on a **yield index**:
  observed yield as a share of the crop's attainable yield.
- Banded on sir's thresholds — marginal `<50%`, moderate `50–69%`, suitable
  `70–79%`, very suitable `≥80%` — held as named constants so one edit re-bands
  the whole app.
- Feeds the recommendation engine's land-suitability signal, replacing the
  soil-only score wherever the map covers the pair.
- A crop × barangay heat map, with the farmer's own barangay pinned to the top.
- Unmapped pairs fall back to soil affinity and are **labelled as inferred**
  rather than presented as observed.

New: `lib/core/logic/suitability_engine.dart`, `lib/features/farmer/suitability_screen.dart`,
`lib/core/widgets/suitability_card.dart`

### 1.4 Demand measured from cooperatives *(note 1.3)*

The saturation denominator was one hardcoded annual constant per crop —
unverifiable, and impossible for anyone on the ground to correct.

- Cooperatives declare what they can absorb, for which crop, over which period,
  at what indicative price, and for which buyer type.
- Commitments feed the Market Saturation Index, pro-rated by how much of the
  window they actually cover.
- Every index states where its demand came from — "declared by 3 cooperatives"
  vs "municipal monthly baseline" — so the number can be defended.

New: `lib/features/cooperative/demand_entry_screen.dart`, `lib/models/demand_signal.dart`

### 1.5 Risk shown before declaring *(note 1.7)*

With the approval chain removed, this is the **only** guardrail between a farmer
and planting into a glut, so it sits directly under the crop picker and updates
live as the form is filled.

- Suitability band for the barangay, saturation band and index, system-derived
  yield and price, projected revenue, and best/worst-case revenue bands.
- A one-line verdict — `Low Risk` / `Proceed with Caution` / `High Risk` — with
  plain-language reasons.
- On `High Risk`, submitting is interrupted with the reason and two better
  alternatives. It **warns, never blocks** — the farmer decides what to plant on
  their own land.
- The verdict shown is stored on the declaration (`riskAtDeclaration`) so the
  study can report whether advice was followed.

New: `lib/features/farmer/widgets/pre_declaration_risk_panel.dart`

### 1.6 Advice at signup *(note 1.7)*

New accounts landed on an empty dashboard, which answers none of the questions a
farmer arrives with. Their barangay is already known, so registration now ends on
what is worth planting there this season — best picks, and what is already
oversupplied. No farm record required.

New: `lib/features/auth/post_signup_advisory_screen.dart`

### 1.7 Tables and heat maps *(note 1.1)*

Saturation was communicated as a coloured chip; the numbers behind it were
invisible.

- The cooperative saturation table is now a **real sortable table** — crop,
  supply, demand (with a provenance tooltip), index to 2 dp, contributing farms,
  band.
- **Crop × month** heat map over 12 months, so a glut can be seen forming.
- **Crop × barangay** heat map — the first analytical use of the barangay field.
- Every cell prints its number; colour never carries meaning alone, which matters
  for colour-blind users and for a phone in direct sunlight.

New: `lib/core/widgets/heatmap_grid.dart`

### 1.8 Registration and identity *(notes 2.1, 2.3)*

- First / middle / last name as **separate fields**, so names can be matched
  against the MAO's RSBSA roster and sorted properly.
- **Confirm password**, which was missing entirely.
- **RSBSA number** captured for farmers — the national farmer-registry ID the MAO
  holds a roster of. Accounts start `pending` and are confirmed by a cooperative
  officer or technician; residency is **verified by someone else, not asserted by
  the person signing up**.
- Unique **username**, shown on the dashboard with a verification badge.
- The **barangay technician** assigned to the farmer's area appears on their
  dashboard with a tap-to-call number — advisory contact, not gatekeeper.

New: `lib/models/barangay_assignment.dart`

### 1.9 Declaration form rebuild *(note 2.5)*

- **Variety is a dropdown**, not free text — twelve spellings of one variety
  cannot be aggregated. Each variety carries its own maturity period, so an
  early-maturing selection produces an earlier harvest date.
- **Area is validated** against the farm's size minus existing active
  declarations, with remaining hectares shown as helper text.
- **Planting cycle from seedlings**: the form asks for the transplant date and
  derives the seedbed date backwards through the crop's nursery period. A
  timeline shows sow → transplant → first harvest.

### 1.10 Supply-chain capture *(notes 1.6, 2.11)*

The MAO portal can only trace supply the mobile app recorded. The production
report now captures **where the harvest actually went** — bagsakan, cooperative,
trader, direct market, another municipality, own consumption — plus the buyer's
name, with a note explaining that selling outside Tubungan is the farmer's
decision and this is only tracking.

---

## 2. Changed behaviour

### 2.1 Declarations are records, not applications *(note 2.6)* ⚠️

The BAW → Technician → MAO approval chain was removed. The MAO has no authority
to approve or deny what a farmer plants on their own land, so an approval gate
misrepresented the real relationship.

- `DeclarationStatus` collapsed to `active` / `harvested` / `cancelled`.
  Retired values still parse, so rows written under the old model load fine.
- The validation stepper is gone; the Overview tab now shows **growth-cycle
  progress** — which stage the crop is in and how much scheduled work is done.
- `declaration_reviews` retained but unused; its history is not destroyed.
- The technician survives as an advisory contact.

**Consequence:** the pre-declaration risk panel ([§1.5](#15-risk-shown-before-declaring-note-17))
is now the only guardrail against planting into a glut.

### 2.2 The projection moved to where it can change a decision *(notes 2.2, 2.8)* ⚠️

Farmers are no longer asked to type an expected yield or a projected price —
figures they cannot know, which the app then presented back as analysis.

| Before | After |
| --- | --- |
| Farmer typed expected yield and price | **System-derived** from calibration × barangay suitability |
| Forecast, break-even and scenario cards on the declaration detail | Shown **before declaring**, in the risk panel, with best/worst-case bands |
| Financials tab opened with a speculative forecast | Opens with **cost to date** against surveyed cost of production, plus the ledger |
| — | Profit, ROI and break-even on the **Harvest tab**, from actual yield and price |

Objective 2 survives on a firmer footing: ROI is still computed, but from data
rather than a guess.

### 2.3 Saturation compares like with like

**The index is a ratio, so both sides must cover the same period.** Supply is now
the tonnage expected to be harvested inside a **90-day forward window** (one
cropping cycle) and demand is that same window's demand, summed across the
calendar months it touches with partial months pro-rated.

Previously every standing declaration was divided by one month of demand — a
unit error that read the pilot dataset at **15.7× demand**.

### 2.4 A cooperative can raise demand, never shrink it

Cooperative-declared demand used to *replace* the municipal baseline. One
association's 25 t overwrote a 125 t baseline, quintupling every index on one
partial data point.

A commitment states that association's **own** absorption — a subset of a market
the baseline already covers, bagsakan throughput included. So demand is now
`max(baseline, cooperative commitments)`. When cooperatives collectively commit
to more than the baseline assumed, that is real evidence and the figure moves.

### 2.5 Demand became seasonal

`demand_baselines` went from one annual figure per crop to **12 monthly figures**.
The same tonnage is a glut in the March harvest peak and a shortfall in the
August lean months.

### 2.6 Farm parcels lost their name *(note 2.4)*

A farmer identifies land by where it is and how big it is. `Farm.name` is gone;
the display label is derived — "Brgy. Igpaho • 1.5 ha".

### 2.7 Navigation

| Portal | Change |
| --- | --- |
| Farmer | `Records` → **`Farm Activity`**, gaining a **Calendar** tab beside Logbook and Incidents — the forward and backward views of one activity stream |
| Farmer | Advisory gains a **Land Suitability** tab |
| Farmer | Dashboard gains **needs-doing-now** and **barangay technician** cards |
| Cooperative | New **Demand** destination |

---

## 3. Defects fixed

### 3.1 Logbook costs never reached the P&L

`LogbookEntry.cost` was written but never became an `Expense`, and
`FinancialEngine` only ever summed `Expense` rows. A farmer who logged "sprayed,
₱2,400" saw it in the logbook and **nowhere in their P&L** — or entered it twice.
Either way the ROI was wrong. Sir spotted this from the outside.

Fixed in [§1.2](#12-one-entry-for-an-activity-and-what-it-cost-note-14), with a
one-shot migration backfilling historical costs.

### 3.2 No area validation existed anywhere

A farmer with 1 ha could declare 50 ha and the app accepted it without comment.
Caught by sir in note 2.5.

### 3.3 Saturation divided a year's supply by a month's demand

Introduced when demand became monthly. Every crop read as catastrophically
oversupplied. See [§2.3](#23-saturation-compares-like-with-like).

### 3.4 One cooperative could shrink municipal demand 5×

See [§2.4](#24-a-cooperative-can-raise-demand-never-shrink-it).

### 3.5 Nested `Scaffold` / `AppBar` inside tabs

`SuitabilityScreen` carried its own app bar *and* a second `TabBar`, then was
embedded in the Advisory tab — a duplicate header with nested tabs. The crop
calendar had the same problem inside Records. Suitability was flattened to one
scroll; the calendar gained an `embedded` flag since it is used both ways.

### 3.6 A nested unbounded `ListView`

The suitability map returned a `ListView` inside the parent's `ListView` — a
layout failure at runtime, not a cosmetic issue. Now a `Column`.

### 3.7 `copyWith` could not clear the cost link

`deleteExpense` called `copyWith(cost: 0, expenseId: '')`, but the `??` fallbacks
set an **empty string** rather than null, so the logbook kept claiming a link to
a deleted expense. Added an explicit `clearCostLink` flag.

### 3.8 Unscoped table scans

Two `fetchAll()` calls read every logbook and expense row in the municipality to
find a single record. Now scoped to the owning farmer.

### 3.9 The seeds carried the duplicate-cost bug they were meant to demonstrate

In both `demo_seed.dart` and `seed.sql`, the ₱6,400 fertilizer and ₱2,100 spray
appeared in the ledger **and** the logbook as unlinked twins — the exact fault
sir described. Now paired.

---

## 4. Data

### 4.1 New datasets

All generated reproducibly by `dart run tool/generate_datasets.dart`. Sir
approved synthetic data for now ("synthetic lang anay").

| Dataset | Rows | Purpose |
| --- | --- | --- |
| `crop_varieties` | 27 | Real PH varieties with per-variety maturity days |
| `crop_growth_stages` | 35 | Nursery → harvest, day 0 = transplant, negative days for the seedbed |
| `crop_activity_schedule` | 317 | The dated agronomic protocol the calendar expands |
| `barangay_suitability` | 384 | 48 barangays × 8 crops |
| `demand_baselines` | 96 | Rebuilt from annual to **monthly** |

Full column documentation in [datasets/README.md](../datasets/README.md).

### 4.2 Reseeded population

The seed put 42 of 50 farmers on one crop at 1.0–1.6 ha each, all harvesting the
same week — 655 t of ampalaya against a municipality absorbing ~125 t a quarter.
Both seeds now model a real upland vegetable association:

```
49 farmers | 32.1 ha planted | 90-day window
crop            farms   supply t   demand t   index   band
Ampalaya          19      168.6      122.3    1.38   High Risk
Eggplant          14      147.8      151.7    0.97   Moderate Risk
Squash             3       33.3      117.4    0.28   Low Risk
Okra               5       24.6      100.3    0.24   Low Risk
String Beans       4       19.2       88.1    0.22   Low Risk
Tomato             3       27.6      132.1    0.21   Low Risk
Pechay             1        3.3       73.4    0.04   Low Risk
Sweet Corn         1        4.8      171.2    0.03   Low Risk
```

Smallholder plots of 0.3–0.9 ha; one crop genuinely oversupplied, one at
balance, six with headroom — all three bands demonstrable instead of a wall of
red. Ampalaya harvests cluster across **five weeks**, which is what a real glut
looks like, rather than every farmer picking the same morning.

### 4.3 Supply chain — a completed season

The current declarations are all still standing, so nothing had been sold and
the MAO's supply-chain dashboard had a **single** record to draw — with no
channel set. It could not answer the question it exists for.

`seed.sql` now backfills a finished cycle: **34 harvests across eight crops**,
each carrying the channel it actually went to and a named buyer.

| Channel | Lots | Tons | Share | Avg ₱/kg |
| --- | ---: | ---: | ---: | ---: |
| Bagsakan / trading post | 14 | 112.6 | 43.8% | 39.49 |
| Cooperative buy-back | 6 | 52.3 | 20.4% | 40.64 |
| Trader / consolidator | 7 | 46.2 | 18.0% | **32.01** |
| Direct to market | 3 | 21.7 | 8.4% | **51.23** |
| Buyer from another municipality | 3 | 19.9 | 7.7% | 45.46 |
| Own consumption | 1 | 4.3 | 1.7% | — |
| **Total** | **34** | **256.9** | | |

**Roughly 26% left the monitored chain** — traders buying at the farmgate and
buyers from Miagao, Igbaras and San Joaquin. That gap is exactly the
"*ay diin nagkadto ang supply? waay na abot sa bagsakan*" the dashboard is meant
to surface.

The price column explains *why* it happens, which is the part a bare volume
chart would miss: a viajero pays **₱32/kg against the bagsakan's ₱39.49** but
collects at the farm, while hauling to the city market earns **₱51.23** at the
cost of transport and a lost day. Farmers are not leaking supply irrationally —
they are responding to a real trade-off.

`demo_seed.dart` gains one finished okra project with its production report, so
the mobile Harvest tab, the realised P&L, and the sold-to capture are no longer
dead screens.


---

## 5. Schema

Apply [`supabase/migrations/002_adviser_revisions.sql`](../supabase/migrations/002_adviser_revisions.sql)
to an existing database, or `schema.sql` for a fresh one. The migration is
idempotent and non-destructive — nothing is dropped and every row is backfilled
before constraints tighten.

**New tables:** `planned_activities`, `demand_signals`, `barangay_assignments`

| Table | Change |
| --- | --- |
| `profiles` | `first_name`, `middle_name`, `last_name`, `username`, `rsbsa_number`, `verification`, `verified_by`, `verified_at`. `full_name` kept nullable for older clients and backfilled by splitting on the last space |
| `crop_declarations` | `seedling_sowing_date`, `risk_at_declaration`; status collapsed to three values, default `active` |
| `expenses` | `logbook_entry_id` |
| `logbook_entries` | `expense_id`, `planned_activity_id` |
| `production_reports` | `sold_to_channel`, `buyer_name` |
| `farms` | `name` made nullable (deprecated) |
| `declaration_reviews` | Retired; status columns converted to text |

The `declaration_status` type is **swapped rather than extended**, because
`ALTER TYPE … ADD VALUE` cannot be used in the same transaction that adds it and
Supabase's SQL editor runs a script as one transaction.

> ⚠️ **The SQL has not been executed against a live database.** Structural lint
> passes (dollar-quote balance, parens, statement termination, repository→table
> coverage) but that is not the same as running it. Apply `002` to a Supabase
> branch or scratch database before touching anything real.

---

## 6. Tests

38 passing, across three suites.

| Suite | Covers |
| --- | --- |
| `engines_test.dart` | Financial realism, legacy status parsing, saturation bands and windows, suitability thresholds and coverage, calendar expansion and rescheduling, risk assessment |
| `app_actions_test.dart` | The real write path against in-memory repositories — activity/cost pairing, deletion in both directions, calendar generation, rescheduling |
| `demo_seed_test.dart` | **Seed plausibility** — association size, smallholder plot sizes, no absurd index, exactly one High band, crop spread, harvest clustering, and that a finished harvest exists with its channel and buyer recorded |

Two are worth calling out as guardrails rather than coverage:

- **`2 ha of tomato projects over 1M pesos of revenue`** — sir's sanity check,
  asserted so a future calibration change fails the build rather than drifting.
- **The seed plausibility suite** — if anyone reseeds unrealistically later,
  these fail rather than the demo quietly becoming nonsense again.

---

## Decisions awaiting confirmation

**A — The projection was moved, not deleted.** `CLAUDE.md` defines Objective 2
as predictive forecasting and ROI. A literal deletion removes the forecasting
half of a stated objective, *and* the millions-per-2-ha figure sir liked **is**
that projection. So the farmer-facing inputs went and the forward-looking
figures moved to the decision point. If he meant delete outright, say so.

**B — The approval chain was fully removed.** Sound reasoning, but it reverses
`CLAUDE.md`'s "states that default to pending approval status". Worth confirming
he wants no non-blocking acknowledgement flag either.

## Still needs real data

| Item | Blocking | Note |
| --- | --- | --- |
| Barangay × crop yields | Suitability map is synthetic | Terrain is assigned deterministically. Replace `terrains` / `terrainFor()` in the generator with the MAO's classification, or overwrite the CSV — no code change needed |
| Threshold definition | Band cut-points | Implemented as *percent of attainable yield*. Percent-of-provincial-average or percent-of-best-barangay would give different maps. One-line change on `SuitabilityBand` |
| Bagsakan throughput | Demand realism | 500 t/yr ampalaya implies ~21 kg per person locally — only defensible as absorption serving Iloilo City. Real trading-post figures would replace it cleanly |
| Crop protocols | Calendar accuracy | Currently modelled from standard practice; ATI guides or the MAO technicians' own protocol would make it authoritative |
