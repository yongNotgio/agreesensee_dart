# AgriSense Mobile — Analytics & Modelling

This document explains the analytical core of AgriSense: the decision engines,
the math behind each metric, the calibration pipeline that feeds them real
parameters, and how everything is wired to the UI so it recomputes in real time.

All of the modelling lives in `lib/core/logic/` as **pure, deterministic,
offline functions** — no external ML service, no network dependency. Given the
same inputs, an engine always returns the same numbers, which makes the stack
testable, fast on low-end devices, and fully functional offline. This is the
concrete expression of the manuscript's "no heavy external ML" delimitation:
descriptive statistics and transparent rules over trained black-box models.

---

## 1. Analytics in three layers

```
┌───────────────────────────────────────────────────────────────┐
│  providers/ (data_providers.dart)                             │  reactive
│    saturationProvider · harvestPeaksProvider ·                │  recompute
│    recommendationsProvider · intercropProvider · …            │  on stream
│      ▲ watch live declarations        │ feed engines           │
├──────┼────────────────────────────────┼───────────────────────┤
│  core/logic/  (seven pure engines)    │                        │  domain math
│    saturation · financial · harvest_sync · recommendation ·   │
│    scenario · suitability · crop_calendar                      │
│      ▲ consume calibration + models                            │
├──────┼────────────────────────────────────────────────────────┤
│  data/market_dataset.dart  (calibration layer)                │  data → params
│    raw history  ──►  per-crop CropCalibration                  │
└───────────────────────────────────────────────────────────────┘
```

**Key design decision:** nothing is a hand-tuned magic number where real data
exists. Each engine accepts a `calibration` map derived from the datasets and
falls back to the bundled `CropCatalog` (`lib/core/constants/app_constants.dart`)
only when the JSON assets cannot be loaded.

The only non-determinism in the whole stack is the live declaration stream from
Supabase — which is exactly what makes the saturation and congestion metrics
update as farmers declare crops.

---

## 2. Calibration layer — data → parameters

`lib/data/market_dataset.dart`

`MarketDataset.fromJson` ingests four asset payloads (agronomics, costs, a
36-month farmgate price history, and demand baselines) and computes one
`CropCalibration` per crop. Everything downstream reads from this, so the
engines stay parameter-free.

| Parameter | How it is derived |
| --- | --- |
| `baselinePricePerKg` | Mean of the **most recent 12 months** of price points |
| `priceP10 / P50 / P90` | Linear-interpolated percentiles over the full series (`_percentile`) |
| `priceCoefficientOfVariation` | σ ÷ μ over the full price history (a volatility index) |
| `bestPriceUplift` | `(p90 − mean) / mean`, clamped to `[0.05, 0.6]` |
| `worstPriceDrop` | `(mean − p10) / mean`, clamped to `[0.05, 0.6]` |
| `meanYield / min / max` | From the agronomics dataset (t/ha → kg/ha) |
| `bestYieldUplift / worstYieldDrop` | `(max − mean)/mean` and `(mean − min)/mean`, clamped |
| `costByCategory / totalCostPerHa` | Surveyed cost of production per hectare |
| `annualDemandTons` | Demand baseline — the saturation denominator |
| `soilSuitability` | 0–1 map keyed by soil type |
| `projectedNetPerHa` | `meanYield × baselinePrice − totalCostPerHa` |

`MarketDataset.fallback()` reconstructs an equivalent calibration from
`CropCatalog` when the JSON assets are unavailable, so the app never loses its
analytics offline.

---

## 3. Market Saturation Index — oversupply core

`lib/core/logic/saturation_engine.dart` · Objectives 1 & 3

The signature metric of the system. It answers: *is the municipality about to
over-produce this crop?*

```
Saturation Index = expected supply (tons) ÷ market demand (tons)
```

- **Supply** = Σ `expectedYieldTons` of all *active* declarations for the crop.
- **Demand** = calibrated `annualDemandTons`, or a cooperative/MAO override.
- **Risk bands** (`levelForIndex`):

| Index | Level | Meaning |
| --- | --- | --- |
| `< 0.85` | Low | Room in the market |
| `0.85 – 1.15` | Moderate | Supply and demand near balance |
| `> 1.15` | High | Oversupply risk |

`forAllCrops` unions the catalog crops with all declared crops (so planners also
see crops with zero current supply) and sorts by index descending, surfacing the
highest-risk crops first. `SaturationResult` also exposes `surplusTons`
(supply above demand) for the cooperative dashboards.

---

## 4. Financial engine — ROI & P&L

`lib/core/logic/financial_engine.dart` · Objective 2

Produces a `FinancialResult` in two modes:

- **Projection** (`FinancialEngine.projection`) — pre-plant forecast:
  `revenue = expectedYield × projectedPrice`, against logged expenses (or an
  estimated input cost when none are logged yet).
- **Realized** (`FinancialEngine.realized`) — post-harvest P&L from an actual
  `ProductionReport` plus logged costs.

Derived metrics on `FinancialResult`:

| Metric | Formula |
| --- | --- |
| Net income | `revenue − totalExpenses` |
| ROI | `netIncome ÷ totalExpenses` |
| Profit margin | `netIncome ÷ revenue` |
| Break-even yield (kg) | `totalExpenses ÷ pricePerKg` |
| Break-even price (₱/kg) | `totalExpenses ÷ yieldKg` |
| Margin of safety | `(yieldKg − breakEvenYieldKg) ÷ yieldKg` |
| Cost per ha | `totalExpenses ÷ areaHa` |
| Net income per ha | `netIncome ÷ areaHa` |

Expenses are also grouped by category (`expensesByCategory`), which is what the
`fl_chart` fiscal breakdowns render. Per-hectare normalizations let projects of
different sizes be compared fairly.

---

## 5. Harvest synchronization — congestion detection

`lib/core/logic/harvest_sync_engine.dart` · Objectives 1 & 3

Buckets active declarations by **crop × ISO week** (each week normalized to its
Monday via `weekStart`) and flags simultaneous market dumping.

- A `HarvestPeak` is **congested** when the number of *distinct farmers*
  harvesting that crop that week is `≥` the threshold (default `5`,
  `AppConstants.harvestCongestionThreshold`).
- `suggestions` emits a mitigation only for congested peaks:
  - **Planting shift** of `clamp(growthDurationDays × 0.2, 7, 30)` days — spread
    the window by roughly a fifth of the growth cycle without missing the season.
  - **Alternatives** drawn from the crop's companion list (intercropping /
    crop-switch), with a human-readable message.
- `projectionForCrop` builds a dense **12-week, zero-filled** time series per
  crop — the supply-line chart on the cooperative dashboard.

---

## 6. Recommendation engine — explainable weighted scoring

`lib/core/logic/recommendation_engine.dart` · Objective 1

Blends four normalized 0–1 signals into a single composite desirability score:

```
score = 0.25·suitability + 0.20·season + 0.30·saturation⁻¹ + 0.25·profit
```

| Signal | Weight | Definition |
| --- | --- | --- |
| Suitability | 0.25 | Soil-specific land suitability from calibration |
| Season | 0.20 | `1.0` if in-season, else `0.35` |
| Saturation (inverse) | **0.30** | `1 − clamp(index, 0, 2) / 2` |
| Profitability | 0.25 | `netPerHa ÷ maxNet` across all crops |

**Saturation carries the most weight (0.30)** — oversupply avoidance is the
paramount goal, so a high index actively suppresses a crop's ranking.

Each `CropRecommendation` ships an explainable `rationale` string (e.g.
*"well-suited to the current dry season, HIGH oversupply risk — consider an
alternative, projected net ≈ ₱42,000/ha"*) rather than an opaque number.

`intercrops` builds mix-and-match pairings from the top single-crop
recommendations using the companion graph, scoring each pair as the average of
its two members' scores and citing their staggered growth cycles.

---

## 7. Scenario / risk engine

`lib/core/logic/scenario_engine.dart` · Phase 8 (Risk & Scenario Analysis)

Shocks price and yield around the baseline projection into three cases:

| Scenario | Price factor | Yield factor |
| --- | --- | --- |
| Best | `1 + bestPriceUplift` (default +15%) | `1 + bestYieldUplift` (default +10%) |
| Expected | `1.00` | `1.00` |
| Worst | `1 − worstPriceDrop` (default −20%) | `1 − worstYieldDrop` (default −15%) |

When a `CropCalibration` is supplied, the uplift/drop factors come from the
crop's **actual p10/p90 price spread and observed yield range** — so the risk
fan reflects that crop's real historical volatility, not a fixed guess. Each
scenario reuses `FinancialEngine.projection` to yield a full P&L.

---

## 8. Reactive wiring

`lib/providers/data_providers.dart`

The engines are pure, so freshness is the providers' job. Each derived provider
`watch`es the raw declaration providers and recomputes automatically after any
write:

| Provider | Engine call |
| --- | --- |
| `saturationProvider` | `SaturationEngine.forAllCrops` |
| `harvestPeaksProvider` | `HarvestSyncEngine.peaks` |
| `harvestSuggestionsProvider` | `HarvestSyncEngine.suggestions` |
| `recommendationsProvider` | `RecommendationEngine.recommend` |
| `intercropProvider` | `RecommendationEngine.intercrops` |

Because the raw declarations come from a Supabase realtime stream (or the local
cache offline), the municipal saturation and congestion analytics update live as
farmers submit declarations.

---

## 9. Objective trace

| Objective | Engines / layers |
| --- | --- |
| **1** — single-crop + intercrop strategy to avoid oversupply | recommendation + saturation + **suitability** + harvest-sync |
| **2** — financial viability & profit margins | financial + scenario (at the decision point) + the expense ledger |
| **3** — cooperative supply-chain coordination | saturation + **demand signals** + harvest projections + market channels |
| **4** — logbook + calamity tracking | **crop calendar** + unified activity/cost capture feeding realized P&L |

---

## 10. Land suitability — where a crop actually grows well

`lib/core/logic/suitability_engine.dart`

The barangay was captured on every profile, farm, and declaration and read by no
engine, so every farmer in Tubungan saw an identical crop ranking. This engine
makes location matter.

**Quantity:** the **yield index** — observed yield as a share of the crop's
attainable yield in the pilot area (0–1). Cut into four bands on thresholds set
by the adviser and held as named constants on `SuitabilityBand`:

| Band | `yield_index` |
| --- | --- |
| Marginally suitable | `< 0.50` |
| Moderately suitable | `0.50 – 0.69` |
| Suitable | `0.70 – 0.79` |
| Very suitable | `≥ 0.80` |

Suitability enters `RecommendationEngine` as the land-suitability signal,
replacing the soil-only score wherever the barangay × crop map covers the pair.
When it does not, the engine falls back to the crop's soil affinity and marks
the result `isMapped: false` so the UI can say the number was inferred rather
than observed.

`SuitabilityEngine.matrix()` produces the crop × barangay grid behind the map
view — a colour-banded, numerically-labelled grid rather than a tiling map,
which keeps it fully offline and legible on a low-end device in daylight.

> **The data is synthetic.** See `datasets/README.md` for how `yield_index` is
> derived and exactly what to replace to make it real. The manuscript must not
> present these values as observed field measurements.

---

## 11. Crop calendar — the protocol, dated

`lib/core/logic/crop_calendar_engine.dart`

The logbook only ever recorded the past. But the app already knows the crop and
the planting date, so it can say *when to fertilise, when to irrigate, when to
spray* rather than waiting to be told after the fact.

`CropCalendarEngine.plan()` expands `crop_activity_schedule` against a
declaration's real planting date into dated `PlannedActivity` rows. Day 0 is
transplant (or direct sowing); nursery and land-preparation operations carry
negative offsets and therefore fall **before** it — which is what makes a
planting cycle *starting from seedlings* representable at all. A single flat
growth-duration number could not express a seedbed period.

| Function | Purpose |
| --- | --- |
| `plan()` | Expand the protocol into dated operations |
| `stages()` | Resolve growth stages to calendar dates (the cycle timeline) |
| `currentStage()` | Which stage a planting is in today |
| `sowingDateFor()` | Seedbed date for nursery crops; null when direct-seeded |
| `harvestDateFor()` | Planting + the **variety's** maturity period |
| `reschedule()` | Re-date pending work after a planting-date change, preserving anything already done |

`reschedule()` deliberately never rewrites history: completed and skipped
operations keep their original dates and status, and only pending ones are
re-derived.

---

## 12. Demand resolution — a denominator with provenance

**The index is a ratio, so both sides must describe the same period.** Supply is
the tonnage expected to be **harvested inside a forward window**
(`SaturationEngine.defaultWindowDays` = 90, one cropping cycle); demand is that
same window's demand. Summing every standing declaration against one month of
demand is a unit error that makes every crop look catastrophically oversupplied
— it inflated the pilot dataset to 15x demand.

`CropCalibration.demandBetween()` sums each calendar month the window touches,
pro-rating partial months, so the denominator keeps its seasonality.

Demand then resolves as follows, carrying its source with it:

| Source | Applies when | `DemandSource` |
| --- | --- | --- |
| Cooperative commitments, pro-rated by their overlap with the window | their total **exceeds** the baseline | `cooperative` |
| The seasonal municipal baseline over the window | otherwise | `baseline` |
| Catalog constant, pro-rated | no calibration row exists | `catalog` |

**A cooperative can raise the denominator but never shrink it.** A commitment
states that association's *own* absorption, which is a subset of the market the
municipal baseline already covers — bagsakan throughput to Iloilo City included.
Letting one association's 25 t replace a 125 t baseline would quintuple every
saturation index on the strength of one partial data point. When cooperatives
collectively commit to *more* than the baseline assumed, that is real evidence
demand is higher, and the figure moves.

`SaturationResult.demand.provenance` is rendered wherever an index appears
("demand 62 t — declared by 3 cooperatives" vs "municipal monthly baseline"), so
the figure can be defended rather than merely asserted.

`SaturationEngine.monthlyMatrix()` extends this across a 12-month horizon:
supply lands in the month of expected harvest and is compared against *that
month's* demand, because the same tonnage is a glut in the harvest peak and a
shortfall in the lean season.

--- | --- | --- |
| 1 | Sum of cooperative `demand_signals` covering today, normalised to a monthly rate | `cooperative` |
| 2 | The crop's monthly baseline for the current month | `baseline` |
| 3 | The bundled catalog constant | `catalog` |

`SaturationResult.demand.provenance` is rendered wherever an index appears
("demand 62 t — declared by 3 cooperatives" vs "municipal monthly baseline"), so
the figure can be defended rather than merely asserted.

`SaturationEngine.monthlyMatrix()` extends this across a 12-month horizon:
supply lands in the month of expected harvest and is compared against *that
month's* demand, because the same tonnage is a glut in the harvest peak and a
shortfall in the lean season.

---

## 13. Two decisions taken from the consultation

Both reverse choices originally drawn from the manuscript, so they are recorded
here explicitly rather than buried in a diff.

### A. The pre-planting projection moved, it was not deleted

The farmer is no longer asked to type an **expected yield** or a **projected
price**. Those are figures a farmer cannot know, which the app then presented
back as analysis — guesswork dressed as a forecast.

- Both are now **system-derived**: calibrated mean yield × area × the barangay's
  suitability index, and the 12-month mean farmgate price.
- They appear **read-only in the pre-declaration risk panel**, alongside
  best/worst-case revenue bands from `ScenarioEngine` — forward-looking analysis
  at the moment it can still change a decision.
- The declaration's Financials tab now shows **cost to date** against the
  surveyed cost of production, plus the expense ledger. Profit and ROI appear on
  the Harvest tab, computed from actual yield and actual selling price.

Objective 2 therefore survives on a firmer footing: ROI is still computed, but
from data rather than from a farmer's guess.

### B. Declarations are records, not applications

The BAW → Technician → MAO approval chain was removed. The MAO has no authority
to approve or deny what a farmer plants on their own land, so an approval gate
misrepresented the real institutional relationship.

- `DeclarationStatus` collapses to `active` / `harvested` / `cancelled`.
  `fromWire` maps every retired value onto a surviving one, so rows written
  under the old model still load.
- `declaration_reviews` is retained but unused; its history is not destroyed.
- The technician survives as an **advisory contact** surfaced on the farmer
  dashboard, not a gatekeeper.

**The consequence worth stating plainly:** with no approval gate, the
pre-declaration risk panel is the *only* thing standing between a farmer and
planting into a glut. That is why it sits directly under the crop picker,
updates live, and interrupts a high-risk submission with the reason and two
alternatives — while never blocking it. The farmer decides; the app advises.

---

## 14. Worked example — two hectares, verified

The adviser's sanity check was that realistic revenue on two hectares should
reach the millions. Traced end to end, from the bundled calibration:

| Step | Source | Tomato, 2 ha |
| --- | --- | --- |
| Mean yield | `crop_agronomics.csv` | 20.0 t/ha → **40,000 kg** |
| Baseline price | mean of last 12 months, `market_prices_monthly.csv` | **₱35.99/kg** |
| Revenue | yield × price | **₱1,439,600** |
| Cost of production | `production_costs.csv` | ₱113,000/ha → **₱226,000** |
| Net income | revenue − cost | **₱1,213,600** |
| ROI | net ÷ cost | **5.37×** |
| Break-even yield | cost ÷ price | 6,280 kg (16 % of expected) |

Ampalaya over the same area nets ≈ ₱1.12 M. The figure is asserted by
`test/engines_test.dart` ("2 ha of tomato projects over 1M pesos of revenue"), so
a future calibration change that quietly breaks it fails the build rather than
drifting unnoticed.

---

## 15. Design notes

- **Pure & synchronous.** Engines import neither Flutter nor Supabase; they take
  models in and return results out. This makes them unit-testable and correct
  regardless of connectivity.
- **Calibrated, not hard-coded.** Real parameters come from historical datasets
  via `MarketDataset`; bundled catalog values are only a fallback.
- **Explainable.** Recommendations and mitigations produce human-readable
  rationale, not just scores — appropriate for a farmer-facing decision aid.
- **Offline-first.** With the calibration fallback and the cached declaration
  set, every metric on every screen is computable with no network.
