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
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

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

1. Create a Supabase project and run [`supabase/schema.sql`](supabase/schema.sql)
   in the SQL editor (tables, enums, RLS, reference-crop seed).
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

## Verifying the build

```bash
flutter analyze        # static analysis (no issues expected)
flutter build apk      # Android
flutter build web      # Web
```
