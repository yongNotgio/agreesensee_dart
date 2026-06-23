# AgriSense Mobile — Architecture & Objective Trace

This document explains how the Flutter codebase is layered and traces each of
the manuscript's four study objectives to the concrete files that implement it.

---

## 1. Layered architecture

```
┌──────────────────────────────────────────────────────────────┐
│  features/  (UI — Farmer & Cooperative portals)              │  ConsumerWidgets
│      ▲ watch providers           │ call AppActions            │
├──────┼───────────────────────────┼───────────────────────────┤
│  providers/  (Riverpod)          ▼                            │  state + DI
│      core_providers · data_providers · app_actions ·         │
│      auth_controller                                          │
│      ▲ read repositories         │ feed engines               │
├──────┼───────────────────────────┼───────────────────────────┤
│  repositories/  (offline-first)  │   core/logic/  (pure math) │  domain
│      SyncedRepository<T> ──────── consumes ──► engines        │
│      ▲ Supabase  │ LocalCache                                 │
├──────┼───────────┼───────────────────────────────────────────┤
│  models/  (entities, 1:1 with Postgres tables)               │  data contract
└──────────────────────────────────────────────────────────────┘
```

**Dependency rule:** UI depends on providers; providers depend on repositories
and engines; repositories depend on models + cache + Supabase; engines depend
only on models. Nothing lower depends on anything higher. The engines import
neither Flutter nor Supabase, so they are pure and testable.

### State management — Riverpod

- `core_providers.dart` — DI roots: `SharedPreferences`, `LocalCache`,
  `SupabaseClient?`, connectivity, and one provider per repository.
- `auth_controller.dart` — `Notifier<AuthState>` owning the session; the router
  redirects off it.
- `data_providers.dart` — `FutureProvider.autoDispose` reads (farmer-scoped and
  municipal) plus **derived** analytics providers (`saturationProvider`,
  `harvestPeaksProvider`, `recommendationsProvider`, …) that `watch` the raw
  declaration providers, so they recompute automatically after any write.
- `app_actions.dart` — the single write surface; each method mutates a
  repository then invalidates exactly the affected providers.

### Offline-first sync — `SyncedRepository<T>`

Every entity repository extends `SyncedRepository<T>` which encapsulates two
modes behind one API:

| | Live mode (Supabase configured) | Demo mode (no credentials) |
|--|--|--|
| Reads | Supabase query → mirror into `CollectionStore` → on failure serve cache | `CollectionStore` (seeded) |
| Writes | Supabase upsert + cache; optimistic local write on failure | `CollectionStore` only |
| Realtime | `supabase.stream()` | one-shot snapshot |

`CollectionStore<T>` is a typed JSON collection persisted in
`SharedPreferences`, keyed by table name — the on-device system of record in
demo mode and the last-synced mirror in live mode.

---

## 2. Objective trace

### Objective 1 — Recommendation module
> *Analyze land suitability, seasonal constraints, and crop saturation to
> recommend single-crop and intercropping strategies, with automated harvest
> timelines to mitigate oversupply.*

| Concern | Implementation |
|---|---|
| Composite scoring | `RecommendationEngine.recommend()` — weighted suitability (0.25) + season (0.20) + inverse saturation (0.30) + profitability (0.25) |
| Intercropping pairs | `RecommendationEngine.intercrops()` over the crop catalog's companion graph |
| Saturation signal | `SaturationEngine.forCrop()` (supply ÷ demand) |
| Harvest timelines | `HarvestSyncEngine.peaks()` + `suggestions()` (stagger advice) |
| UI | `features/farmer/advisory_screen.dart` (Recommendations + Harvest Sync tabs); declaration form auto-derives harvest date from growth duration |

### Objective 2 — Financial modeling tool
> *Record profit margins from projected prices and land area, compare
> recommended vs. saturated crops (risk assessment), track actual input costs to
> compute final P&L.*

| Concern | Implementation |
|---|---|
| Pre-plant projection | `FinancialEngine.projection()` → revenue, net income, ROI, profit margin |
| Break-even | `breakEvenYieldKg`, `breakEvenPricePerKg`, `marginOfSafety` |
| Risk scenarios | `ScenarioEngine.build()` → best/expected/worst net income |
| Input-cost ledger | `Expense` model + `expense_sheet.dart`; category donut chart |
| Realized P&L | `ProductionReport` + `FinancialEngine.realized()`; plan-vs-actual variance |
| UI | `features/farmer/declaration_detail_screen.dart` (Financials + Harvest tabs), `core/widgets/charts.dart` |

### Objective 3 — Supply-chain dashboard
> *Forward-looking supply projection with harvest synchronization to prevent
> simultaneous dumping, and automatic identification of alternative markets /
> buy-back programs for predicted surpluses.*

| Concern | Implementation |
|---|---|
| Supply projection | `HarvestSyncEngine.projectionForCrop()` → 12-week series, charted vs. demand |
| Saturation table | `SaturationEngine.forAllCrops()` |
| Congestion detection | `HarvestSyncEngine.peaks()` (`isCongested` when farmers ≥ threshold) |
| Surplus routing | `surplus_screen.dart` matches each crop's `surplusTons` to `MarketChannel`s that accept it; capacity coverage meter |
| Buy-back channels | `MarketChannel` model + `market_channel_sheet.dart` |
| Member monitoring | `coop_profile_screen.dart` aggregates active declarations by crop/farmer |
| UI | `features/cooperative/` (Overview, Supply, Surplus, Association tabs) |

### Objective 4 — Digital logbook & incident reporting
> *Record agronomic events (e.g. fertilizer application) and report
> calamity-induced losses to streamline subsidy verification.*

| Concern | Implementation |
|---|---|
| Agronomic logbook | `LogbookEntry` model + `logbook_form_screen.dart` (activity type, input used, quantity, cost) |
| Incident reporting | `CalamityReport` model + `calamity_form_screen.dart` (type, loss %, affected area, damage markers) |
| Verification lifecycle | `VerificationStatus` enum (submitted → under review → verified → endorsed) shown as status chips |
| UI | `features/farmer/records_screen.dart` (Logbook + Incidents tabs) |

---

## 3. Workflow phases → screens

The `Simplified Workflow.md` phases map onto the UI as follows:

| Phase | Where in the app |
|------|------------------|
| 1. Registration & farm profiling | Register screen → `farm_form_screen.dart` |
| 2. Crop planning & declaration | `declaration_form_screen.dart` (status defaults to *Pending Validation*) |
| 3. Validation & approval (BAW→Tech→MAO) | Read-only `_ValidationTimeline` in the declaration detail (writes happen on the web/admin side) |
| 5. Market saturation analysis | `SaturationEngine` surfaced on dashboards & detail |
| 6. Crop recommendation engine | Advisory tab |
| 7. Financial forecasting | Financials tab |
| 8. Risk & scenario analysis | Scenario card (Financials tab) |
| 9. Harvest synchronization | Advisory ▸ Harvest Sync; Cooperative ▸ Supply |

---

## 4. Extending the system

- **New crop** → add a `CropProfile` to `CropCatalog` (and a `crops` row in
  `schema.sql`); every engine picks it up automatically.
- **New entity** → add a model in `models/`, a `SyncedRepository` subclass, a
  provider in `core_providers.dart`, and an action in `app_actions.dart`.
- **Tune the recommender** → adjust the weights at the top of
  `RecommendationEngine`, or the bands in `SaturationEngine`.
- **Real backend** → run `supabase/schema.sql`, pass the `--dart-define`s; no
  application code changes required.
