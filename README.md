# AgriSense — Mobile Portals (Flutter)

**Integrated Agricultural Decision Support System (IADSS)** for the Municipal
Agriculture Office of **Tubungan, Iloilo**. This repository contains the
**Flutter mobile client** implementing the two field-facing portals:

| Portal | User | Study objectives served |
|--------|------|-------------------------|
| 🌱 **Farmer** | Small-to-medium-scale farmers | 1 (recommendations), 2 (financial modeling), 4 (logbook & incident reporting) |
| 🤝 **Cooperative** | Farmers' associations | 3 (supply-chain dashboard, harvest synchronization, buy-back routing) |

> The MAO / admin validation dashboard is the **web** client (per the manuscript
> scope) and is intentionally out of mobile scope; the `mao`, `technician`, and
> `baw` roles are still modeled so role-routing degrades gracefully.

---

## How it maps to the four study objectives

1. **Recommendation module** — `lib/core/logic/recommendation_engine.dart`,
   `saturation_engine.dart`, `harvest_sync_engine.dart`. Blends land
   suitability, seasonal fit, market saturation, and projected profit into an
   explainable score; surfaces single-crop **and** intercropping (mix-and-match)
   strategies plus automated harvest timelines.
   → *Farmer ▸ Advisory tab.*
2. **Financial modeling tool** — `financial_engine.dart`, `scenario_engine.dart`.
   Projects revenue from price × yield × area, computes **ROI, net income,
   break-even, and margin of safety**, compares best/expected/worst risk
   scenarios, tracks actual input costs (fertilizer, labor…) and the realized
   post-harvest **P&L**.
   → *Farmer ▸ Crops ▸ a declaration ▸ Financials / Harvest tabs.*
3. **Supply-chain dashboard** — `saturation_engine.dart` + `harvest_sync_engine.dart`.
   Forward-looking 12-week supply projection per crop vs. demand, harvest
   congestion detection, predicted-surplus routing to **buy-back programs /
   alternative market channels**.
   → *Cooperative ▸ Overview / Supply / Surplus tabs.*
4. **Digital logbook & incident reporting** — `logbook_entry.dart`,
   `calamity_report.dart`. Dated agronomic events (e.g. fertilizer application)
   and high-priority calamity reports capturing **crop-loss %** and damage
   markers to streamline subsidy verification.
   → *Farmer ▸ Records tab.*

A full objective-by-objective trace lives in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), and the complete end-to-end
system flow (every portal, screen, function, and cross-portal data flow) is in
[`docs/SYSTEM_FLOW.md`](docs/SYSTEM_FLOW.md).

---

## Tech stack

- **Flutter (Dart 3.11)**, Material 3, responsive & high-contrast for
  low-to-mid-tier devices.
- **Riverpod** for state management.
- **go_router** for role-based routing.
- **Supabase** (`supabase_flutter`) — Auth, PostgreSQL, realtime, RLS.
- **fl_chart** — financial breakdowns, scenario bars, supply line charts.
- **Offline-first** caching layer (`shared_preferences` + a typed
  `CollectionStore`), with a Supabase write-through mirror.

---

## Running the app

### Option A — Demo mode (no backend, fully offline)

Just run it. With no Supabase credentials the app seeds realistic sample data
locally and every screen is navigable.

```bash
flutter pub get
flutter run            # or: flutter run -d chrome
```

**Seeded demo accounts** (any password works in demo mode):

| Role | Email |
|------|-------|
| Farmer (Juan Dela Cruz) | `farmer@agrisense.ph` |
| Cooperative (Maria Santos) | `coop@agrisense.ph` |

The seed deliberately over-declares **Ampalaya** in one harvest week so the
saturation index reads **High** and harvest synchronization flags a congested
window — making the recommendation and supply-chain logic visible immediately.

### Option B — Live Supabase backend

1. Create a Supabase project and, in the SQL editor, run **in order**:
   - [`supabase/schema.sql`](supabase/schema.sql) — all-portal schema: tables,
     enums, RLS for farmer/cooperative/MAO/technician/BAW, validation audit
     table, reference-crop seed.
   - [`supabase/seed.sql`](supabase/seed.sql) — populates the database so it's
     not empty: **working login accounts for every role**, 50+ farmers, a
     realistic Ampalaya oversupply cluster, expenses, logbook, a calamity
     report, buy-back channels, 36 months of prices, and demand baselines.

   Both are idempotent and were validated end-to-end against PostgreSQL.

   **Seed login accounts** (password `AgriSense123!`):

   | Email | Role | Portal |
   |-------|------|--------|
   | `farmer@agrisense.ph` | Farmer | Mobile |
   | `coop@agrisense.ph` | Cooperative | Mobile |
   | `mao@agrisense.ph` | MAO admin | Web |
   | `baw@agrisense.ph` | Barangay Agri Worker | Web |
   | `tech@agrisense.ph` | Agri Technician | Web |

2. Launch with credentials injected at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon/publishable key>
```

The same repository surface (`lib/repositories/`) now targets Supabase; reads
mirror into the offline cache, and writes are optimistic so the app keeps
working through connectivity drops.

---

## Project structure

```
lib/
├── main.dart                 # bootstrap: cache seed / Supabase init
├── app.dart                  # MaterialApp.router + theme
├── core/
│   ├── config/               # compile-time config & demo-mode switch
│   ├── theme/                # Material 3 theme + palette
│   ├── router/               # go_router with role redirect
│   ├── constants/            # crop catalog, barangays, thresholds
│   ├── utils/                # formatters, validators, parsing, id gen
│   ├── cache/                # offline LocalCache + CollectionStore
│   ├── network/              # connectivity service
│   ├── logic/                # ← the decision engines (Objectives 1–3)
│   │   ├── saturation_engine.dart
│   │   ├── financial_engine.dart
│   │   ├── scenario_engine.dart
│   │   ├── harvest_sync_engine.dart
│   │   └── recommendation_engine.dart
│   └── widgets/              # shared widgets + fl_chart wrappers
├── models/                   # entities (1:1 with Supabase tables)
├── repositories/             # offline-first Supabase repositories + seed
├── providers/                # Riverpod providers, controllers, actions
└── features/
    ├── auth/                 # splash, login, register, role gate
    ├── farmer/               # Farmer portal (Objectives 1, 2, 4)
    └── cooperative/          # Cooperative portal (Objective 3)
```

---

## The decision engines (pure & unit-testable)

All business math is isolated in `lib/core/logic/` as pure functions:

| Engine | Key output | Formula highlights |
|--------|-----------|--------------------|
| `SaturationEngine` | Market Saturation Index + low/moderate/high band | `index = expected_supply ÷ demand` |
| `FinancialEngine` | ROI, net income, break-even, margin of safety | `ROI = (revenue − expenses) ÷ expenses` |
| `ScenarioEngine` | Best / Expected / Worst net income | price/yield shocks ±10–20% |
| `HarvestSyncEngine` | Harvest peaks, congestion flags, stagger advice | bucket by crop × ISO week |
| `RecommendationEngine` | Ranked crops + intercrop pairs | weighted: suitability·0.25 + season·0.20 + low-saturation·0.30 + profit·0.25 |

Because they are decoupled from Supabase and Flutter, they can be exercised in
isolation and are the same functions the manuscript's "math/logic matrices"
describe.

---

## Data modelling & calibration (Objectives 1 & 2)

The engines are **rule-based**, so the datasets *calibrate* their parameters
(they are not ML training weights). Factual-but-synthetic datasets, grounded in
real Philippine vegetable economics, live in:

- [`datasets/`](datasets/) — human-readable CSVs + a full
  [data dictionary](datasets/README.md) (for the thesis appendix)
- [`assets/data/`](assets/data/) — JSON the app loads at runtime
- [`tool/generate_datasets.dart`](tool/generate_datasets.dart) — deterministic
  generator (`dart run tool/generate_datasets.dart` reproduces them exactly)

| Dataset | Calibrates |
|---------|-----------|
| `market_prices_monthly` (36 mo × 8 crops) | baseline price, P10/P90 → **scenario** bands, volatility |
| `production_costs` (PHP/ha by category) | break-even, default expense estimate, profit signal |
| `crop_agronomics` (yield range, soil/seasonal suitability) | yield bands, recommendation suitability |
| `demand_baselines` (annual tons) | **Market Saturation Index** denominator |

`lib/data/market_dataset.dart` parses these into a `CropCalibration` per crop
(mean-of-12-months price, percentile-based scenario factors, cost roll-ups,
demand), loaded at startup by `lib/data/dataset_loader.dart` and threaded into
the engines via Riverpod. The Financials tab shows a **Price calibration** card
exposing the derived figures. To use real MAO figures, edit the generator or
overwrite the JSON — no code changes needed.

---

## Completing the thesis — the MAO web portal

The mobile app is the two field portals; the admin/validation surface is a
**web** portal. A complete, build-ready plan (shared backend, validation state
machine, screens, deployment, milestones) is in
[`docs/WEB_PORTAL_GUIDE.md`](docs/WEB_PORTAL_GUIDE.md).

---

## Verifying the build

```bash
flutter analyze        # static analysis (no issues expected)
flutter build apk      # Android
flutter build web      # Web
```
