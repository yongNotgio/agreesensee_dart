# Adviser Feedback — Mobile Scope & Implementation Plan

> **Status: implemented.** Every mobile item below has been built. The two held
> decisions were resolved as recommended (projection *moved* to the decision
> point, not deleted; approval chain removed) — see
> [`ANALYTICS_AND_MODELLING.md` §13](ANALYTICS_AND_MODELLING.md) for what was
> actually done and why. **Both still need sir's confirmation**, and the
> barangay suitability map ships as documented synthetic data pending real MAO
> figures (see `datasets/README.md`).

Consolidated triage of both consultation batches against the AgriSense Flutter
codebase. Batch 1 = the saturation / suitability / costing notes. Batch 2 = the
registration, declaration-form, and calendar notes.

Two batch-2 items **reverse architectural decisions taken from the manuscript**
and are held for confirmation — see [Decisions needed](#decisions-needed-before-coding).

---

## 1. Scope verdict

### Batch 1

| # | Note | Verdict | Current state |
| --- | --- | --- | --- |
| 1.1 | Tabled numbers / heatmap for saturation | Mobile — partly built | `_SaturationTable` is a row list, no index or demand column; no heatmap |
| 1.2 | Saturation depends on market demand | Mobile — data gap | One flat annual tons figure per crop, municipality-wide |
| 1.3 | Measure demand from cooperatives | Mobile — not built | `demandOverridesProvider` reads only the bundled dataset |
| 1.4 | Merge expense entry into the activity log | Mobile — confirmed defect | `LogbookEntry.cost` never becomes an `Expense`; P&L under-reports |
| 1.5 | Barangay suitability + yield thresholds | Mobile first — not built | Barangay collected everywhere, read by no engine |
| 1.6 | MAO supply-chain leakage tracking | Web | Mobile prerequisite: capture buyer on production report |
| 1.7 | Risk shown before declaring / at signup | Mobile — not built | Declaration form shows no risk signal |
| 1.8 | Realistic revenue, millions per 2 ha | Mobile — already satisfied | Tomato 2 ha ≈ ₱1.44 M revenue, ₱1.21 M net |

### Batch 2

| # | Note | Verdict | Current state |
| --- | --- | --- | --- |
| 2.1 | Split first/last name, confirm password, Tubungan verification | **New** — mobile | `Profile.fullName` is one field; no confirm-password; no residency check at all |
| 2.2 | Remove expected yield & projected price from crop planning | **New** — mobile, ⚠ see Decision A | Both are farmer-entered fields on the declaration form |
| 2.3 | Dashboard shows farmer username + assigned barangay technician | **New** — mobile | Dashboard shows `fullName`; no username field; no technician-assignment model |
| 2.4 | Remove farm name from profile | **New** — mobile | `Farm.name` is required and validated |
| 2.5 | Variety dropdown · area-exceeds-land error · remove yield/price · planting cycle from seedlings | **New** — mobile (4 sub-items) | Variety is free text; **no area validation exists at all**; cycle is one flat `growth_days` |
| 2.6 | Remove MAO validation — system recommends, MAO cannot control planting | **New** — mobile, ⚠ see Decision B | 4-step `pending → bawApproved → technicianVerified → approved` chain is modelled and rendered |
| 2.7 | MAO dashboard map of planting concentration | Web | Barangay is captured per declaration; data is ready |
| 2.8 | Remove pre-planting projection | **New** — mobile, ⚠ see Decision A | `_FinancialsTab` renders forecast + break-even + scenario cards |
| 2.9 | Calendar of recommended dates from the plant cycle (fertilise / irrigate / spray) | **New** — mobile, large | Logbook is purely reactive; nothing is ever scheduled or suggested |
| 2.10 | Land suitability | **Duplicate** of 1.5 | — |
| 2.11 | Supply chain dashboard | **Duplicate** of 1.6 — web | Reinforces the mobile capture prerequisite; promoted from optional to required |

**Net new mobile work from batch 2: notes 2.1, 2.3, 2.4, 2.5, 2.9, plus the two
held decisions.** Notes 2.2 and 2.8 are the same instruction stated twice.
Notes 2.10 and 2.11 are duplicates. Note 2.7 is web.

---

## 2. Decisions needed before coding

### Decision A — Removing the pre-planting projection (notes 2.2, 2.5, 2.8)

**The conflict.** `CLAUDE.md` and the manuscript define Objective 2 as
"predictive forecasting … ROI calculation systems, and operational expense
ledgers required to evaluate profit margins against market saturation
thresholds." A literal removal of the pre-planting projection deletes the
forecasting half of a stated thesis objective, and the panel sir liked in note
1.8 (millions per 2 ha) *is* that projection.

**Likely intent.** Read alongside note 2.9 — where sir wants the system to
*tell* the farmer the schedule rather than ask — the consistent theme is
**stop making the farmer guess numbers they cannot know**. A farmer typing
"expected yield" and "projected price" into a form is entering a guess the app
then presents back as analysis.

**Recommended reconciliation** (satisfies both):

- **Remove** the farmer-entered `Expected yield (kg)` and
  `Projected price (₱/kg)` inputs from the declaration form.
- **Remove** the speculative pre-plant forecast, break-even, and scenario cards
  from the declaration detail Financials tab.
- **Keep** yield and price as *system-derived, clearly-labelled advisory
  figures* inside the recommendation — "3-year data for your barangay:
  ampalaya averages 12 t/ha at ₱46.61/kg" — sourced from calibration, never
  typed by the farmer.
- **Keep** the realised P&L, ROI, and expense ledger untouched; they run on
  logged costs and actual harvest, which is real data, not a forecast.

That preserves Objective 2 on a defensible footing while doing what sir asked.

**Please confirm with sir:** does he want the projection *deleted*, or moved
out of the farmer's hands and into the system's recommendation?

### Decision B — Removing the validation chain (note 2.6)

**The conflict.** `CLAUDE.md` specifies declarations "including tracking states
that default to pending approval status", and the workflow document describes a
BAW → Technician → MAO validation chain. It is modelled in
`DeclarationStatus`, rendered by `_ValidationTimeline`, counted on the
dashboard, and audited by the `declaration_reviews` table.

**Sir's reasoning is sound** — MAO has no authority to approve or deny what a
farmer plants on their own land, so an approval gate misrepresents the real
institutional relationship.

**Recommended reconciliation.** Declarations become **records, not
applications**:

- Collapse `DeclarationStatus` to `active` / `harvested` / `cancelled`.
- New declarations save as `active` immediately — no pending state, no queue.
- Delete `_ValidationTimeline` and the pending count on the dashboard.
- Retire `declaration_reviews`; leave the table in place but unused so existing
  data is not destroyed.
- The technician role survives as **advisory contact** (note 2.3), not
  gatekeeper — which is exactly the relationship sir described.

**Note the knock-on effect:** with no approval gate, the *only* guardrail
against a farmer planting into a glut is the recommendation shown before they
declare. That makes note 1.7 (pre-declaration risk panel) the single most
important item in this plan, not an optional nicety.

**Please confirm with sir:** full removal as above, or keep a non-blocking
"acknowledged by BAW" flag for data-quality purposes?

---

## 3. Implementation phases

Ordered by dependency. Phases 1 and 2 are structural and everything downstream
sits on them.

### Phase 1 — Registration, identity, and profile (notes 2.1, 2.3, 2.4)

1. **Split the name.** Replace `Profile.fullName` with `firstName` / `lastName`
   (+ optional `middleName`), keeping a computed `fullName` getter so the ~15
   existing display sites do not all have to change at once. Migrate
   `profiles.full_name` to `first_name` / `last_name` in `supabase/schema.sql`
   with a backfill that splits on the last whitespace. Update `initials`.
2. **Confirm password.** Add the field to `RegisterScreen` with a
   `Validators.matches` rule. Also add a password-strength hint — currently
   `Validators.password` is the only gate.
3. **Residency verification.** Add `rsbsaNumber` and `verificationStatus`
   (`unverified` / `pending` / `verified`) to `Profile`. Registration captures
   the RSBSA number (the national farmer registry ID, which MAO already holds a
   roster of) plus barangay; the account is created `pending` and the coop or
   technician confirms it. **This is a policy decision — see data item 7.**
   Gate nothing behind verification initially except a visible badge; blocking
   unverified farmers from declaring is a second, separate decision.
4. **Username.** Add a unique `username` to `Profile` and the `profiles` table,
   for display and eventually for login. Show it on the farmer dashboard header
   under the greeting.
5. **Assigned technician.** New model `BarangayAssignment`
   (`id, barangay, technicianId, role, assignedAt`) plus table, repository, and
   an `assignedTechnicianProvider` keyed on the farmer's barangay. Render a
   contact card on the farmer dashboard — name, contact number, tap-to-call.
6. **Remove farm name.** Drop `Farm.name` and its form field; replace display
   uses with a derived label (`'Brgy. ${barangay} — ${area} ha'`). Drop the
   column from `farms`.

### Phase 2 — Declaration form rebuild (notes 2.2, 2.5, 2.6, 2.8, 1.7)

Blocked on Decisions A and B.

1. **Variety dropdown.** New dataset `crop_varieties.csv`
   (`crop_id, variety, maturity_days, notes`), loaded through `MarketDataset`.
   Replace the free-text field with a dependent dropdown that reloads on crop
   change. Keep an `Other` option with a text fallback so an unlisted local
   variety is still recordable. **Data item 5.**
2. **Area validation.** This is a live bug — a farmer with 1 ha can currently
   declare 50 ha. Validate entered area against
   `farm.totalAreaHa − Σ(active declarations on that farm)`, and show the
   remaining hectares as helper text under the field. Reject with a specific
   message naming the available balance, and account for intercropping (a
   companion crop shares the same parcel and must not double-count).
3. **Remove yield and price inputs** per Decision A.
4. **Planting cycle from seedlings.** Decompose the flat `growth_days` into
   stages — `nursery`, `transplant`, `vegetative`, `flowering`, `harvest` —
   in a new `crop_growth_stages.csv`. The form asks for the **sowing/seedling
   date**, and derives transplant and harvest dates from the stage table
   instead of adding one lump number. **Data item 6.**
5. **Remove the validation chain** per Decision B.
6. **Pre-declaration risk panel** (note 1.7) — now load-bearing. A live panel
   under the crop picker showing suitability band for the barangay (Phase 5),
   saturation band and index at the expected harvest month (Phases 4 and 6),
   the system-derived yield/price advisory (Decision A), and a one-line verdict.
   On `High risk`, intercept submit with a confirmation naming the reason and
   the top two alternatives — warn, never block. Persist the shown verdict as
   `riskAtDeclaration` so the thesis can report whether advice was followed.
7. **Post-signup advisory.** Route new farmers to a dismissible "Recommended
   for Barangay X this season" screen instead of an empty dashboard. Barangay
   from the profile is enough; no farm record required.

### Phase 3 — Crop cycle calendar with unified cost capture (notes 1.4, 2.9)

These two notes are one feature. Note 1.4 says a logged activity should carry
its cost; note 2.9 says activities should be *scheduled in advance* from the
plant cycle. Together they make the logbook proactive.

**The defect first (note 1.4).** `LogbookEntry.cost` is persisted but never
becomes an `Expense`, and `FinancialEngine` sums `Expense` rows only. A farmer
who logs "sprayed, ₱2,400" sees it in the logbook and nowhere in the P&L — or
duplicates it in the expense sheet. Either way the ROI is wrong.

1. Add `expenseId` to `LogbookEntry` and `logbookEntryId` to `Expense`, with
   matching nullable FK columns and indexes.
2. Add `ActivityType.defaultExpenseCategory`:
   `landPrep→labor`, `planting→seed`, `fertilizing→fertilizer`,
   `irrigation→irrigation`, `weeding→labor`, `pestControl→pesticide`,
   `scouting→other`, `harvesting→labor`, `other→other`.
3. In `LogbookFormScreen`, replace the bare cost field with a collapsed
   `+ Add cost incurred` control that expands to amount (required once open)
   and category (pre-filled, editable). Require a linked declaration when a
   cost is entered — an unattributed expense cannot reach any P&L — and say so
   in a validation message rather than dropping it silently.
4. `AppActions.saveActivityWithCost(entry, {expense})` writes the expense,
   stamps its id on the entry, writes the entry, and invalidates
   `logbookProvider`, `farmerExpensesProvider`, and
   `expensesForDeclarationProvider`. Roll back the expense if the entry write
   fails. Mirror with `deleteActivityWithCost`.
5. Backfill existing `LogbookEntry` rows carrying a cost into real expenses —
   one-shot SQL migration plus matching `demo_seed.dart` changes.

**Then the calendar (note 2.9).**

6. New dataset `crop_activity_schedule.csv`
   (`crop_id, days_after_sowing, activity_type, title, typical_input,
   typical_qty_per_ha, unit, notes`) — the agronomic protocol per crop.
   **Data item 6.**
7. New engine `lib/core/logic/crop_calendar_engine.dart` that expands a
   declaration's sowing date against the schedule into concrete dated
   `PlannedActivity` items, shifted by the actual planting date and clipped at
   the harvest date.
8. New model `PlannedActivity` (`id, declarationId, activityType, scheduledOn,
   title, suggestedInput, suggestedQty, status`) with status
   `pending` / `done` / `skipped`, plus table and repository. Generate the plan
   on declaration save; regenerate on planting-date edit.
9. New screen `lib/features/farmer/crop_calendar_screen.dart` — a month grid
   plus an agenda list of upcoming operations across all active declarations,
   colour-coded by activity type, with overdue items surfaced first.
10. **Close the loop:** tapping a planned activity opens `LogbookFormScreen`
    pre-filled with its type, title, and suggested input — the farmer confirms,
    adds the actual cost via step 3, and the planned item flips to `done`.
    That is the single "may gin ubra nga activity, may gin incur nga cost"
    interaction sir described, now with the system proposing what comes next.
11. Local notifications for upcoming operations are an obvious extension but
    add a plugin dependency and a permissions flow — propose separately rather
    than bundling here.

### Phase 4 — Real, seasonal, coop-sourced demand (notes 1.2, 1.3)

Saturation Index = expected supply ÷ demand, and demand is currently one
hardcoded annual constant per crop — no seasonality, no provenance, no way for
a cooperative to correct it.

1. Replace `demand_baselines.csv` with a monthly file
   (`crop_id, month, demand_tons, source`); expose `demandForMonth()` on
   `CropCalibration`. **Data item 3.**
2. New model `DemandSignal` (`id, cooperativeId, cropId, periodStart,
   periodEnd, demandTons, pricePerKg?, buyerType, notes`), table, and
   repository. `buyerType` ∈ `bagsakan`, `institutional`, `processor`,
   `trader`, `retail`.
3. New screen `demand_entry_screen.dart` on the cooperative portal — "we can
   absorb N tons of crop X between A and B at ₱Y/kg". This is the mechanism
   sir asked for: demand measured from coops.
4. Rework `demandOverridesProvider` into a `FutureProvider` resolving per crop:
   (a) sum of active `DemandSignal` rows covering today, (b) monthly dataset
   baseline, (c) catalog constant. Add a `DemandSource` enum to the result.
5. Extend `SaturationResult` with `demandSource` and label it in the UI —
   "demand 62 t, declared by 3 cooperatives" vs "demand 45 t, municipal
   baseline". Defensibility at the defence depends on this label.

### Phase 5 — Barangay land suitability (notes 1.5, 2.10)

Barangay is captured in the profile, the farm, and every declaration, and read
by no engine — so every farmer in Tubungan sees an identical crop ranking.

1. New dataset `barangay_suitability.csv`
   (`barangay, crop_id, yield_index, observations, source_year`), where
   `yield_index` is observed yield as a fraction of attainable yield.
   **Data item 1.**
2. New `lib/core/logic/suitability_engine.dart` with a `SuitabilityBand` enum
   and named threshold constants — draft `<0.50` marginal, `0.50–0.69`
   moderately suitable, `0.70–0.79` suitable, `≥0.80` very suitable — pending
   **data item 2**. Cite them in `docs/ANALYTICS_AND_MODELLING.md`.
3. Blend into `RecommendationEngine`: the suitability signal becomes the
   barangay index when present, falling back to the existing soil score. Leave
   the 0.25/0.20/0.30/0.25 weights alone unless the ranking visibly degrades;
   if it does, propose new weights with a written rationale rather than
   retuning silently.
4. New `suitability_screen.dart`: barangay picker (defaulting to the farmer's
   own) over a colour-banded crop list with band, index, and plain-language
   reason. Reachable from Advisory and from the declaration form.
5. Render a **crop × barangay grid** for the farmer's barangay and its
   neighbours — banded cells, horizontally scrollable. No tiling-map library;
   a grid satisfies "map" offline on a low-end device.

### Phase 6 — Saturation tables and heatmaps (note 1.1)

1. New `lib/core/widgets/heatmap_grid.dart` — reusable, horizontally
   scrollable, colour scale plus legend, tap-through cells. Print the numeral
   in every cell; never encode meaning in hue alone.
2. Replace `_SaturationTable` with a real table: crop, expected supply (t),
   demand (t), **index to 2 dp**, contributing declarations, band. Sortable.
3. **Crop × month** saturation heatmap over 12 months, from each active
   declaration's expected harvest month against monthly demand (Phase 4). Add
   `SaturationEngine.monthlyMatrix(...)`.
4. **Crop × barangay** supply heatmap on the coop side — the first analytical
   use of the barangay field.
5. On the farmer dashboard, replace the single worst-crop card with a compact
   table of the farmer's own crops plus the top three municipal risks.

### Phase 7 — Financial model reconciliation (notes 1.8, 2.2, 2.8)

Small once Decision A lands.

1. Apply Decision A to `_FinancialsTab` and the declaration form.
2. Document the two-hectare worked example per crop in
   `docs/ANALYTICS_AND_MODELLING.md` — inputs, formula, output — so sir's
   "millions per 2 ha" figure is traceable at the defence. Tomato: 20 t/ha ×
   ₱35.99/kg = ₱719,800/ha → 2 ha = ₱1.44 M revenue, ≈ ₱1.21 M net.
3. Add a regression test asserting a 2 ha tomato projection exceeds ₱1 M, so a
   future calibration change cannot quietly break it.

### Phase 8 — Mobile capture for the web portal (notes 1.6, 2.7, 2.11)

The supply-chain dashboard and the MAO planting map are web deliverables, but
the web portal can only show what mobile recorded. Raised twice, so treat as
required, not optional.

1. Add to `ProductionReport`: `soldToChannel` (`bagsakan`, `cooperative`,
   `trader`, `direct_market`, `neighbouring_municipality`, `own_consumption`,
   `other`), `buyerName`, `soldOutsideMunicipality`. Surface in
   `production_report_sheet.dart`.
2. Barangay is already on every declaration, so the MAO planting map (2.7)
   needs no further mobile work.

That is the entire mobile obligation for the web features.

---

## 4. Datasets and decisions to supply

| # | Item | Blocks | Shape | Notes |
| --- | --- | --- | --- | --- |
| 1 | Barangay × crop yield/suitability | Phase 5 | `barangay, crop_id, yield_index, observations, source_year` | **Critical.** 48 barangays × 8 crops. MAO barangay-level yield records, area planted/harvested, or a Tubungan soil/elevation/rainfall map convertible to an index. Without one, this stays synthetic and the manuscript must say so. |
| 2 | Threshold definition from sir | Phase 5 | — | The 50/70/80 % bands need a denominator. Percent of *attainable* yield, of the *provincial average*, or of the *best-performing barangay*? The three produce three different maps. |
| 3 | Monthly demand baselines | Phase 4 | `crop_id, month, demand_tons, source` | 96 rows. Ideal source: Tubungan bagsakan throughput or MAO market monitoring. Absent that, it will be synthesised from current annual figures × a seasonal index — and labelled synthetic. |
| 4 | Coop absorption reality-check | Phase 4 | Free-form | Roughly what can the pilot coop absorb per crop per month, and who are the standing buyers (schools, hospitals, resorts, processors)? Determines whether the demand form asks for tons/week or tons/season. |
| 5 | Variety list per crop | Phase 2 | `crop_id, variety, maturity_days, notes` | **New.** Locally-planted varieties for the 8 crops. Seed-supplier catalogues or the MAO/ATI recommended-variety list both work. Demo data currently has only Galaxy, Casino, Smooth Green, Sandigan. |
| 6 | Crop growth stages + activity protocol | Phases 2, 3 | `crop_id, days_after_sowing, activity_type, title, typical_input, typical_qty_per_ha, unit` | **New and central to note 2.9.** For each crop: nursery duration, transplant day, and the dated schedule of fertiliser splits, irrigation intervals, and spray windows. ATI production guides or the MAO technicians' own protocol are the natural sources. Without this the calendar has nothing to recommend. |
| 7 | Residency-verification policy | Phase 1 | — | **Decision, not data.** How should "taga-Tubungan" be proven? Recommended: RSBSA number captured at signup, confirmed against the MAO roster by a technician or coop officer. Alternatives are phone OTP (proves a number, not residency) or barangay-certificate photo upload (needs storage and a review queue). |
| 8 | Real farmgate prices *(optional)* | Phases 4, 7 | `crop_id, year, month, price_per_kg` | Current 36-month history is synthetic-but-grounded. A real PSA/MAO series upgrades every projection at zero code cost — the loader already reads this shape. |
| 9 | Real cost of production *(optional)* | Phase 7 | `crop_id, seed, fertilizer, labor, irrigation, pesticide, transport, equipment` | An ATI or MAO cost-of-production table drops straight into the existing file. |

**Blocking:** items 1 and 2 for Phase 5; item 5 for Phase 2; item 6 for
Phase 3; item 7 for Phase 1. Item 3 blocks only the *real-data* version of
Phase 4 — the code path and coop entry screen can be built ahead of it.

---

## 5. Suggested sequencing

1. **Get Decisions A and B answered.** Both change the shape of the declaration
   form and the financial module; building Phase 2 before they land means
   building it twice.
2. **Phase 3, first half** — the cost/activity merge. A genuine defect, needs no
   external data, and is the change sir described most concretely.
3. **Phase 1** — registration and identity. Self-contained, needs only the
   item 7 policy decision.
4. **Phase 2** — declaration rebuild, once the decisions and item 5 arrive.
5. **Phase 3, second half** — the calendar, once item 6 arrives.
6. **Phase 4** against current data, upgraded when item 3 arrives.
7. **Phase 5** once items 1 and 2 arrive.
8. **Phase 6** last — it visualises what Phases 4 and 5 produce.
9. **Phases 7 and 8** are small and can slot in anywhere after their decisions.
