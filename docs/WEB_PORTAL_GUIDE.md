# Building the AgriSense Web Portal (MAO / Admin) — Completing the Thesis

The mobile app delivers the two **field** portals (Farmer, Cooperative). The
thesis is *completed* by the third stakeholder surface — the **Municipal
Agriculture Office (MAO) administrative web portal** — which closes the
validation loop (Phase 3) and the governance/subsidy loop the field portals feed
into. This guide is a concrete, build-ready plan for that web portal.

> **Already done for you:** the data layer is shared and portal-agnostic. The
> Supabase schema ([`supabase/schema.sql`](../supabase/schema.sql)) already
> models the `mao` / `technician` / `baw` roles, the full
> `declaration_status` validation chain, calamity `verification_status`, and RLS
> read-access for governance roles. The decision engines in
> [`lib/core/logic/`](../lib/core/logic) are pure Dart and run unchanged on the
> web.

---

## 1. What the web portal must do (scope)

Mapped to the manuscript's Level-1 DFD (Process 2.0 Consolidate & Store, Process
4.0 Geospatial & Supply Analytics) and the study objectives:

| Module | Purpose | Objective |
|--------|---------|-----------|
| **Validation queue & review** | BAW → Agricultural Technician → MAO approval of crop declarations; approve / reject / request correction with notes | Phase 3 (workflow) |
| **Supply-chain governance dashboard** | Municipal-wide saturation, harvest-synchronization peaks, oversupply alerts, barangay clustering | 3 |
| **Calamity verification & subsidy** | Review incident reports, verify loss %, endorse for subsidy allocation | 4 |
| **Reference-data management** | Maintain `crops`, `market_prices`, and `demand_baselines` — the same data that calibrates the mobile engines | 1 & 2 |
| **Reports / analytics** | Production forecasts, P&L roll-ups, ISO/IEC 25010 evidence | all |

---

## 2. Choose the stack

### ✅ Recommended — **Flutter Web, reusing this repository**

The single strongest choice for a thesis: **one codebase, one data contract,
one set of engines**, evaluated as one system.

- Reuse `models/`, `repositories/`, `core/logic/`, `data/` **verbatim**.
- Add an `admin` feature module + role routing; nothing else changes.
- Deploy the same project to web hosting; the mobile and web clients are the
  same Flutter app with role-gated shells.

### Alternative — **Next.js / React + `@supabase/supabase-js`**

More "web-native" (SSR, SEO, rich admin component libraries) but you
**reimplement** the models and the saturation/financial/harvest engines in
TypeScript. Only pick this if a web-only team is building it in parallel. If you
do, port the formulas in [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) §2 exactly so
both clients agree.

The rest of this guide assumes the **Flutter Web reuse** path.

---

## 3. Backend — already provisioned

**All web-portal backend objects now ship in the consolidated
[`supabase/schema.sql`](../supabase/schema.sql)** (validated end-to-end against
PostgreSQL), so there is **no separate migration to run**. Specifically it
already includes:

- The **`declaration_reviews`** audit table (who advanced a declaration, when,
  why) + its RLS.
- **Governance update policies** so `mao`/`technician`/`baw` can advance the
  validation chain (`decl_gov_update`) and verify calamities
  (`calamity_gov_update`).
- **Reference/calibration write policies** so the MAO can maintain `crops`,
  `market_prices`, and `demand_baselines` (`crops_write`, `prices_write`,
  `demand_write`).
- The role helper **`public.auth_user_role()`** used by every policy.

Apply `schema.sql` then `seed.sql` (which creates a working `mao@agrisense.ph`
account, password `AgriSense123!`) and you can sign straight into the web
portal. The market-price rows MAO maintains are exactly what
[`lib/data/dataset_loader.dart`](../lib/data/dataset_loader.dart) reads to
calibrate the engines — so MAO data entry directly improves farmer forecasts.
(In production, point `DatasetLoader` at the `market_prices` / `demand_baselines`
tables instead of the bundled JSON.)

---

## 4. The validation state machine (Phase 3)

`declaration_status` already encodes the chain. Enforce **role-gated**
transitions:

```
pending ──BAW──▶ baw_approved ──Technician──▶ technician_verified ──MAO──▶ approved
   │                  │                              │
   └── reject / request_correction (any reviewer) ───┘
```

| Current status | Role allowed to act | Forward transition |
|----------------|---------------------|--------------------|
| `pending` | BAW | `baw_approved` |
| `baw_approved` | Technician | `technician_verified` |
| `technician_verified` | MAO | `approved` |
| any active | BAW/Tech/MAO | `correction_requested` or `rejected` |

Implement as a small service that (1) checks the actor's role matches the
current step, (2) updates the declaration, (3) writes a `declaration_reviews`
audit row. In Flutter, add it next to `app_actions.dart`:

```dart
// lib/providers/admin_actions.dart  (web portal only)
Future<void> advanceDeclaration({
  required CropDeclaration d,
  required DeclarationStatus to,
  required Profile reviewer,
  String? note,
}) async {
  final client = ref.read(supabaseClientProvider)!;
  await client.from('crop_declarations').update({
    'status': to.wire,
    'reviewer_note': note,
  }).eq('id', d.id);
  await client.from('declaration_reviews').insert({
    'declaration_id': d.id,
    'reviewer_id': reviewer.id,
    'reviewer_role': reviewer.role.wire,
    'from_status': d.status.wire,
    'to_status': to.wire,
    'note': note,
  });
  ref.invalidate(validationQueueProvider);
}
```

The mobile farmer already **renders this chain** read-only
(`_ValidationTimeline` in `declaration_detail_screen.dart`), so once the web
portal advances a status the farmer sees it update — closing the loop.

---

## 5. Screens to build (Flutter Web)

Add `lib/features/admin/` and a route gate. Reuse the shared widgets and charts.

1. **AdminShell** — left `NavigationRail` (web-appropriate) with: Dashboard,
   Validation, Supply Chain, Calamities, Reference Data, Reports.
2. **Validation queue** — filter declarations by status/barangay; a review
   screen showing farm photos, the declaration, and **Approve / Verify /
   Request Correction / Reject** buttons gated by `reviewer.role` and the
   current step. Reuse `SaturationEngine` to warn the reviewer if approving adds
   to an oversupplied crop.
3. **Supply-chain dashboard** — feed *all* declarations into
   `SaturationEngine.forAllCrops`, `HarvestSyncEngine.peaks/suggestions`, and the
   `SupplyLineChart`; add a barangay breakdown table and (optional) a
   `flutter_map` choropleth of production clusters.
4. **Calamity verification** — queue of reports; set
   `verification_status` submitted → under_review → verified → endorsed; compute
   estimated subsidy from `loss_percent × affected_area × calibrated value`.
5. **Reference-data management** — CRUD for `crops`, `market_prices`,
   `demand_baselines` (the calibration inputs). Forms reuse `AppTextField` etc.
6. **Reports** — production forecast, validated-area totals, P&L roll-ups;
   export CSV.

### Route gate change

In [`app_router.dart`](../lib/core/router/app_router.dart), route admin roles to
the new shell instead of the "unsupported" screen:

```dart
String _homeFor(UserRole? role) => switch (role) {
  UserRole.farmer       => Routes.farmer,
  UserRole.cooperative  => Routes.coop,
  UserRole.mao ||
  UserRole.technician ||
  UserRole.baw          => Routes.admin,   // ← new AdminShell
  _                     => Routes.unsupported,
};
```

Gate it to web with `kIsWeb` if you want the admin portal web-only.

---

## 6. Responsive layout for web

- Use `LayoutBuilder` / `MediaQuery`: `NavigationRail` ≥ 1000 px, `NavigationBar`
  below. The existing cards already use `ConstrainedBox(maxWidth: …)`.
- Master-detail: declaration list + review pane side-by-side on wide screens.
- Tables: `DataTable` / `PaginatedDataTable` for the validation and reference
  queues.

---

## 7. Deployment

- **Backend:** the existing Supabase project (Auth, Postgres, RLS, Storage for
  farm/calamity photos).
- **Web build:** `flutter build web --release` →
  host on **Firebase Hosting**, **Vercel**, **Netlify**, or **Supabase Storage +
  CDN**. Inject the same `--dart-define=SUPABASE_URL/ANON_KEY`.
- Add a CI step (GitHub Actions) running `flutter analyze` + `flutter test` +
  `flutter build web` on push.

---

## 8. Milestone plan

| Sprint | Deliverable |
|--------|-------------|
| 1 | Run `schema.sql` + §3 policies; seed a `mao` account; AdminShell + route gate |
| 2 | Validation queue + role-gated review + audit log (Phase 3 complete) |
| 3 | Supply-chain governance dashboard (reuse engines) + barangay breakdown |
| 4 | Calamity verification + subsidy estimate |
| 5 | Reference-data CRUD wired to live calibration; reports/CSV export |
| 6 | Responsive polish, deployment, ISO/IEC 25010 evaluation build |

---

## 9. ISO/IEC 25010 evaluation hooks

The manuscript evaluates functional suitability, usability, and reliability.
Build in evidence: the validation audit log (functional suitability +
traceability), responsive layouts and the same Material 3 design language as
mobile (usability/consistency), and the offline-first repository layer +
Supabase realtime (reliability). Reuse the same respondent instrument across all
three portals so results are comparable.

---

### Summary

Because the mobile app already ships the shared models, RLS-ready schema,
validation-status enum, and pure decision engines, the web portal is
**additive**: a backend policy migration (§3), a state-machine service (§4), and
an `admin` feature module (§5) — no rework of the core. That keeps the whole
IADSS a single coherent system for evaluation, which is exactly what completes
the thesis.
