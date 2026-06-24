# AgriSense — End-to-End System Flow

This document explains **how the entire AgriSense IADSS works end to end**: the
three stakeholder portals, every screen and its functions, and how data flows
between them through the shared Supabase backend and the decision engines.

- **Mobile (this repo):** Farmer portal + Cooperative portal
- **Web (planned — see [`WEB_PORTAL_GUIDE.md`](WEB_PORTAL_GUIDE.md)):** MAO / Admin portal
- **Backend:** Supabase (Auth, PostgreSQL, RLS, Realtime, Storage)
- **Brains:** pure decision engines in [`lib/core/logic/`](../lib/core/logic),
  calibrated by datasets in [`assets/data/`](../assets/data)

---

## 1. The big picture

```
        ┌──────────────────────── MOBILE (Flutter) ────────────────────────┐
        │                                                                   │
   ┌────────────┐                                   ┌──────────────────┐
   │  FARMER     │  declarations, expenses,          │  COOPERATIVE      │
   │  PORTAL     │  logbook, calamity reports        │  PORTAL           │
   │            │ ───────────────┐   ┌───────────── │  (Association)    │
   │ Obj 1,2,4  │                │   │  supply,      │  Obj 3            │
   └────────────┘                ▼   ▼  surplus      └──────────────────┘
                          ┌───────────────────┐             ▲
                          │     SUPABASE       │             │ reads municipal
                          │  Postgres + Auth   │◀────────────┘ dataset
                          │  RLS + Realtime    │
                          └───────────────────┘
                                ▲     ▲
            validates, governs  │     │  maintains reference / calibration data
        ┌───────────────────────┘     └───────────────────────┐
        │                  WEB (Flutter Web)                    │
   ┌──────────────────────────────────────────────────────────────┐
   │  MAO / ADMIN PORTAL                                            │
   │  validation chain · supply governance · subsidy · ref data    │
   └──────────────────────────────────────────────────────────────┘

                 ┌───────────── DECISION ENGINES (pure Dart) ─────────────┐
                 │  Saturation · Financial · Scenario · HarvestSync ·      │
                 │  Recommendation   ← calibrated by datasets/             │
                 └────────────────────────────────────────────────────────┘
```

Everything is **one data contract**: each portal reads/writes the same Supabase
tables; the engines run on whichever portal needs them (the same Dart code runs
on mobile and web).

---

## 2. Actors, roles & access

| Role (`user_role`) | Portal | Can do |
|--------------------|--------|--------|
| `farmer` | Mobile — Farmer | Own farm/declarations/expenses/logbook/calamity; read recommendations & forecasts |
| `cooperative` | Mobile — Cooperative | Read municipal declarations (supply/saturation); manage own buy-back/market channels |
| `baw` | Web | First validation of declarations |
| `technician` | Web | Technical verification of declarations |
| `mao` | Web | Final approval; calamity verification/subsidy; reference-data & calibration management |

Access is enforced by **Row Level Security** (see [`supabase/schema.sql`](../supabase/schema.sql)):
farmers see only their own rows; cooperatives/MAO/technician/BAW get read access
to the municipal dataset; MAO gets write access to validation, calamity
verification, and reference tables.

---

## 3. The end-to-end lifecycle

The full journey, from a farmer signing up to municipal planning, with the
portal responsible for each step:

```
 PHASE / STEP                          PORTAL            DATA EFFECT
 ─────────────────────────────────────────────────────────────────────────────
 1  Register + farm profiling          Farmer (mobile)   profiles, farms
 2  Declare crop (intent)              Farmer (mobile)   crop_declarations
                                                          status = PENDING
 ───────────────────── validation chain (Phase 3) ─────────────────────────────
 3a BAW validation                     Web (BAW)         → baw_approved
 3b Technician verification            Web (Technician)  → technician_verified
 3c MAO approval                       Web (MAO)         → approved  (+ audit)
 ───────────────────── analytics activate on "approved" ───────────────────────
 4  Municipal dataset consolidation    Supabase          all approved declarations
 5  Market Saturation Index            engines           supply ÷ demand → band
 6  Crop recommendations               engines           ranked + intercrop
 7  Financial forecast (ROI/P&L)       engines           per declaration
 8  Risk & scenario analysis           engines           best/expected/worst
 9  Harvest synchronization            engines           peaks + stagger advice
 ───────────────────── operations & governance ────────────────────────────────
 10 Logbook + expenses                 Farmer (mobile)   logbook_entries, expenses
 11 Calamity report                    Farmer (mobile)   calamity_reports (submitted)
 11b Calamity verification → subsidy   Web (MAO)         → verified → endorsed
 12 Harvest + production report        Farmer (mobile)   production_reports
                                                          declaration → harvested
 13 Realized P&L (plan vs actual)      Farmer (mobile)   computed
 14 Supply projection + surplus routing Cooperative      market_channels matching
 15 Supply governance + planning       Web (MAO)         dashboards, reports
```

Two feedback loops make it a *system*, not a set of forms:

- **Validation loop:** the web portal advances a declaration's status; the
  farmer's mobile app renders that progress live (the read-only validation
  timeline) — so the farmer always knows where their declaration stands.
- **Calibration loop:** the MAO maintains market prices & demand on the web;
  those rows recalibrate the engines; farmers get sharper forecasts and
  recommendations on mobile.

---

## 4. MOBILE — Farmer portal (functions by screen)

Shell: [`farmer_shell.dart`](../lib/features/farmer/farmer_shell.dart) — 5
bottom-nav tabs in an `IndexedStack` (state persists per tab) with an offline /
demo banner.

### 4.1 Home — `FarmerDashboardScreen`
| Element | Function |
|---------|----------|
| KPI grid | Active crops, planted area, projected revenue (Σ expected yield × price), next harvest countdown |
| Oversupply watch | Shows the single highest-risk `SaturationResult`; green "all clear" if none high |
| Active declarations | Top 3 active declarations → tap to detail |
| FAB "Declare Crop" | Opens the declaration form |
| Pull-to-refresh | Invalidates declarations/expenses providers |

### 4.2 Crops — `DeclarationsScreen` → form / detail
| Screen | Functions |
|--------|-----------|
| List | Active vs Closed groups; each card shows status chip, harvest date, yield, revenue |
| **`DeclarationFormScreen`** | Create/edit a declaration. Picks crop → auto-fills **calibrated** baseline price & expected yield (yield/ha × area) and **auto-derives harvest date** (planting + growth duration). Choose variety, area, barangay, planting date, projected price, **intercropping companions** (mix-and-match chips), notes. Submits as **Pending Validation**. |
| **`DeclarationDetailScreen`** — 3 tabs | |
| · Overview | Declaration data; **validation timeline** (BAW→Tech→MAO stepper, read-only); market-saturation detail for the crop |
| · Financials | **Forecast card** (revenue, expenses, net income, **ROI**); **Price calibration card** (baseline, P10–P90, volatility, cost/ha, demand — derived from the dataset); **break-even** (yield & price, margin of safety); **scenario chart** (best/expected/worst net income); **expense ledger** (donut by category + swipe-to-delete; add via `ExpenseSheet`) |
| · Harvest | Record post-harvest results via `ProductionReportSheet` → marks declaration **harvested**, computes **realized P&L** and **plan-vs-actual** variance |

### 4.3 Advisory — `AdvisoryScreen` (2 tabs) — Objective 1
| Tab | Functions |
|-----|-----------|
| Recommendations | Ranked single-crop list; each card shows a composite **score badge** and four **signal bars** (suitability, season, low-saturation, profitability), rationale, net/ha & cycle length. Plus **intercropping pairs** with combined score |
| Harvest Sync | Congestion summary; **stagger suggestions** for crowded windows (shift N days / intercrop / alternative crop); upcoming **harvest peaks** with congested flags |

### 4.4 Records — `RecordsScreen` (2 tabs) — Objective 4
| Tab | Functions |
|-----|-----------|
| Logbook | Dated agronomic entries (activity type, input used, quantity, cost); add via `LogbookFormScreen`; swipe-to-delete |
| Incidents | Calamity reports with **loss-meter**, affected area, est. loss value, **verification status**; report via `CalamityFormScreen` (type, date, barangay, affected crop, affected area, **loss % slider**, description) |

### 4.5 Account — `FarmerProfileScreen`
| Element | Function |
|---------|----------|
| Identity + lifetime stats | Declarations, harvested count, total area |
| Contact + cooperative | From profile / `cooperativeProvider` |
| **Farm profile** | View/edit via `FarmFormScreen` (Phase 1: name, barangay, area, soil type, previously-planted crops, prior activities) |
| Sign out | Ends session → router returns to login |

---

## 5. MOBILE — Cooperative portal (functions by screen)

Shell: [`coop_shell.dart`](../lib/features/cooperative/coop_shell.dart) — 4
tabs. The cooperative reads the **municipal** declaration set (all farmers), not
just one farmer's.

### 5.1 Overview — `CoopDashboardScreen`
| Element | Function |
|---------|----------|
| KPI grid | Projected supply (Σ active tons), participating farmers, **high-risk crops** count, projected **surplus** (Σ above demand) |
| Oversupply alerts | Every crop at **High** saturation with supply vs demand & surplus |
| Harvest congestion | Crowded harvest windows + stagger/buy-back advice |

### 5.2 Supply — `SupplyProjectionScreen` — Objective 3 core
| Element | Function |
|---------|----------|
| Crop selector | Choice chips per crop |
| 12-week supply curve | `SupplyLineChart` of weekly projected harvest volume vs a demand reference line; congested weeks marked red |
| Saturation index detail | Big index number + supply/demand + surplus narrative |
| All-crops table | Every crop's supply + saturation band |

### 5.3 Surplus — `SurplusScreen` — Objective 3 routing
| Element | Function |
|---------|----------|
| Absorption capacity | Predicted surplus vs total channel capacity (coverage meter) |
| Surplus routing | For each crop with surplus, matches **buy-back / market channels** that accept it; shows coverage |
| Channels list | Buy-back programs & alternative markets (capacity, price, crops, notes); add via `MarketChannelSheet`; swipe-to-delete |

### 5.4 Association — `CoopProfileScreen`
| Element | Function |
|---------|----------|
| Cooperative profile | Name, barangay, admin, contact |
| Stats | Members, buy-back capacity |
| **Member supply monitoring** | Aggregates active member declarations by crop (tons + farmer count) |
| Sign out | Ends session |

---

## 6. WEB — MAO / Admin portal (functions by screen)

Planned; full build plan in [`WEB_PORTAL_GUIDE.md`](WEB_PORTAL_GUIDE.md). Reuses
the same models, repositories, and engines.

| Screen | Functions |
|--------|-----------|
| **Admin Dashboard** | Municipal totals: pending validations, validated area, oversupply hotspots, calamity queue |
| **Validation queue & review** | Filter declarations by status/barangay; review farm photos + data; **Approve / Verify / Request Correction / Reject** gated by role + current step; writes `reviewer_note` and a `declaration_reviews` audit row |
| **Supply-chain governance** | Same engines as the cooperative, municipal-wide; barangay breakdown + optional choropleth map |
| **Calamity verification** | Queue of reports; advance `verification_status` submitted → under_review → verified → **endorsed (subsidy)**; estimate subsidy from loss % × area × calibrated value |
| **Reference-data management** | CRUD for `crops`, `market_prices`, `demand_baselines` — the **calibration inputs** the mobile engines consume |
| **Reports** | Production forecasts, validated-area totals, P&L roll-ups, CSV export |

---

## 7. Cross-portal data flows (sequence views)

### 7.1 Crop declaration → validation → analytics
```
Farmer(mobile)         Supabase                 Web(BAW/Tech/MAO)     Engines
   │  create decl(pending) │                          │                  │
   ├──────────────────────▶│  insert crop_declarations│                  │
   │                       │◀── farmer sees Pending    │                  │
   │                       │   review + advance        │                  │
   │                       │◀─────────────────────────┤ baw_approved      │
   │                       │◀─────────────────────────┤ technician_verified
   │                       │◀─────────────────────────┤ approved (+audit) │
   │  timeline updates ◀───│  (realtime / refresh)     │                  │
   │                       │  approved decls ─────────────────────────────▶ Saturation,
   │  recommendations ◀────────────────────────────────────────────────────  HarvestSync,
   │  forecasts       ◀────────────────────────────────────────────────────  Recommendation
```

### 7.2 Calamity report → subsidy verification
```
Farmer(mobile)            Supabase              Web(MAO)
   │ report(submitted) ──▶ calamity_reports        │
   │                      │◀── review queue ────────┤ under_review
   │                      │◀────────────────────────┤ verified
   │                      │◀────────────────────────┤ endorsed (subsidy)
   │ status chip ◀────────│  (realtime / refresh)   │
```

### 7.3 Calibration loop (Objectives 1 & 2)
```
Web(MAO) maintains  ─▶ market_prices / demand_baselines (Supabase)
                          │
                          ▼  DatasetLoader (or live query)
                    MarketDataset → CropCalibration per crop
                          │  (baseline price, P10/P90 → scenario bands,
                          │   cost/ha, demand, suitability)
                          ▼
         Financial · Scenario · Recommendation · Saturation engines
                          ▼
            Farmer(mobile) sees calibrated forecasts & advice
```

---

## 8. The decision engines

All pure functions in [`lib/core/logic/`](../lib/core/logic); consume models +
calibration, emit results. Used identically on mobile and (future) web.

| Engine | Input | Output | Core formula |
|--------|-------|--------|--------------|
| `SaturationEngine` | active declarations + demand | index + low/moderate/high band, surplus tons | `index = Σ expected_supply ÷ demand` |
| `FinancialEngine` | yield, price, area, expenses | revenue, net income, **ROI**, break-even, margin of safety | `ROI = (revenue − expenses) ÷ expenses` |
| `ScenarioEngine` | baseline + volatility bands | best/expected/worst net income | price/yield × calibrated factors |
| `HarvestSyncEngine` | declarations | peaks per crop×week, congestion flags, stagger advice, 12-wk projection | bucket by crop × ISO week; flag ≥ threshold farmers |
| `RecommendationEngine` | farm, declarations, season, calibration | ranked crops + intercrop pairs | weighted: suitability·0.25 + season·0.20 + low-saturation·0.30 + profit·0.25 |

Calibration source: [`lib/data/market_dataset.dart`](../lib/data/market_dataset.dart)
turns the datasets into per-crop parameters (see
[`datasets/README.md`](../datasets/README.md)).

---

## 9. Data & sync layer

```
 UI (ConsumerWidget)
   │ watch providers / call AppActions
   ▼
 Riverpod providers  (core_providers · data_providers · app_actions · auth_controller)
   │ read repositories                       │ feed engines
   ▼                                         ▼
 SyncedRepository<T>  ───────── consumes ──► decision engines
   │  Supabase (live)   │  LocalCache (offline mirror / demo store)
   ▼                    ▼
 Postgres tables ◀── write-through / optimistic
```

- **Offline-first:** every repository extends `SyncedRepository<T>`. Live mode
  reads Supabase and mirrors into a `CollectionStore` (SharedPreferences); on
  failure it serves cache; writes are optimistic. **Demo mode** (no credentials)
  uses the seeded local store as the system of record.
- **Reactivity:** `AppActions` mutate a repository then invalidate the affected
  providers; derived analytics (saturation, harvest, recommendations) `watch`
  the declaration providers and recompute automatically.
- **Realtime (live mode):** repositories expose `watch()` over
  `supabase.stream()` so cross-portal changes (e.g. MAO approval) propagate.

---

## 10. Status state machines

**Declaration** (`declaration_status`) — driven mobile→web→mobile:
```
draft ─▶ pending ─BAW─▶ baw_approved ─Tech─▶ technician_verified ─MAO─▶ approved ─▶ harvested
            │                                                              
            └─▶ correction_requested ─▶ (edit & resubmit)     any active ─▶ rejected
```

**Calamity** (`verification_status`) — driven mobile→web:
```
submitted ─▶ under_review ─▶ verified ─▶ endorsed (subsidy)
                          └─▶ declined
```

---

## 11. One-paragraph summary

A **farmer** registers, profiles their farm, and declares a crop on **mobile**;
the declaration enters the **web** validation chain (BAW → Technician → MAO).
Once approved it joins the **municipal dataset**, which the **engines** turn into
a saturation index, crop recommendations (single + intercropping), a financial
forecast (ROI, break-even, best/worst scenarios), and harvest-synchronization
advice — all calibrated by market datasets the **MAO** maintains. The farmer logs
activities and, if disaster strikes, files a calamity report that the **MAO**
verifies and endorses for subsidy. The **cooperative** watches the same municipal
supply, anticipates surpluses, and routes them to buy-back/alternative markets.
Each portal reads and writes the same Supabase backend, so the three surfaces act
as one integrated decision-support system — end to end.
