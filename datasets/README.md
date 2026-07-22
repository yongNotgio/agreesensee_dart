# AgriSense Calibration Datasets

Factual-but-synthetic datasets that **calibrate the rule-based decision
engines** behind study Objectives 1 (recommendation) and 2 (financial
modelling). They are *not* machine-learning training weights — AgriSense uses
deterministic agronomic/economic models (per the manuscript's explicit "no
heavy ML" delimitation), and these rows supply the real-world parameters those
models read instead of hand-tuned constants.

> **Provenance.** Values are synthetic but grounded in real Philippine /
> Western-Visayas high-value-vegetable economics (farmgate price ranges, typical
> yields, and cost-of-production structures published by DA / PSA / ATI).
> Generated deterministically by [`tool/generate_datasets.dart`](../tool/generate_datasets.dart)
> — re-run `dart run tool/generate_datasets.dart` to reproduce byte-for-byte.

The app consumes the JSON copies in [`assets/data/`](../assets/data); the CSVs
here are the human-readable equivalents for the thesis appendix.

---

## 1. `market_prices_monthly.csv` — 36-month farmgate price history

288 rows = 8 crops × 3 years (2023–2025) × 12 months. A seasonal index lifts
prices in the wet/typhoon lean months (Jul–Sep) and lowers them in the dry
harvest glut (Feb–Apr), with a ~4 %/yr inflation trend and ±3 % deterministic
noise. Each crop's amplitude reflects its real volatility (tomato & pechay
swing most; corn least).

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier (FK to all other files) |
| `year` | int | 2023–2025 |
| `month` | int | 1–12 |
| `price_per_kg` | numeric | Farmgate price, PHP/kg |

**Calibrates:** baseline price (mean of last 12 months), price percentiles
(P10/P50/P90 → best/worst **scenario** bands), and the coefficient of variation
(volatility indicator).

## 2. `crop_agronomics.csv` — yield & suitability

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier |
| `name`, `category` | text | Display metadata |
| `seasons` | text | `dry`/`wet`, `\|`-separated → seasonal suitability |
| `growth_days` | int | Planting→harvest duration → harvest-timeline derivation |
| `yield_mean_t_ha` / `min` / `max` | numeric | Yield distribution (t/ha) → break-even & yield **scenario** bands |
| `soil_clay_loam` / `loam` / `sandy_loam` | numeric | Land-suitability score 0–1 by soil type |

**Calibrates:** land suitability + seasonal fit (recommendation), expected-yield
defaults, yield scenario range.

## 3. `production_costs.csv` — cost of production per hectare

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier |
| `seed`,`fertilizer`,`labor`,`irrigation`,`pesticide`,`transport`,`equipment` | numeric | PHP/ha by category |
| `total_per_ha` | numeric | Sum (PHP/ha) |

**Calibrates:** the default expense estimate when a farmer hasn't logged costs,
the break-even point, and the profitability signal in the recommender.

## 4. `demand_baselines.csv` — municipal market demand, by month

96 rows = 8 crops × 12 months. Saturation is a seasonal question: the same
tonnage is a glut in the March harvest peak and a shortfall in the August lean
months, so a single annual figure could not express it.

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier |
| `month` | int | 1–12 |
| `demand_tons` | numeric | Municipal demand for that month (t) |
| `annual_demand_tons` | numeric | Yearly total, for reference |
| `source` | text | Provenance of the figure |

**Calibrates:** the denominator of the **Market Saturation Index**
(`index = expected_supply ÷ demand`).

> **Superseded at runtime.** Demand a cooperative actually declares in the app
> (`demand_signals`) takes precedence over these baselines. The UI labels which
> layer a figure came from, so the number is never anonymous.

## 5. `crop_varieties.csv` — locally-grown varieties

27 rows. Variety used to be free text, which made the field useless for
analysis — a dozen spellings of the same variety cannot be aggregated. It is now
a bounded choice, and each variety carries its own maturity period so an
early-maturing selection produces an earlier harvest date.

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier |
| `variety` | text | Variety name as farmers and seed suppliers use it |
| `maturity_days` | int | Transplant/sowing → first harvest for this variety |
| `notes` | text | Why a farmer might pick it |

**Feeds:** the variety dropdown and the derived harvest date.

## 6. `crop_growth_stages.csv` — the cycle, from seedbed to harvest

35 rows. Day 0 is transplant (or direct sowing); nursery stages carry **negative**
days. This is what makes a planting cycle *starting from seedlings* representable
— a single flat growth-duration number cannot express a seedbed period.

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier |
| `stage` | text | `nursery`, `establishment`, `vegetative`, `reproductive`, `harvest` |
| `label` | text | Display name |
| `day_from`, `day_to` | int | Offsets from day 0; negative before planting |

**Feeds:** the growth-cycle timeline, the derived seedbed date, and the current
stage shown on a declaration.

## 7. `crop_activity_schedule.csv` — the agronomic protocol

317 rows. The dated schedule of operations for each crop: land preparation,
nursery care, fertiliser splits, irrigation intervals, protective sprays,
scouting, and harvest picks.

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier |
| `days_after_planting` | int | Offset from day 0; negative for nursery / land prep |
| `activity_type` | text | Maps to `ActivityType` |
| `title` | text | What the farmer is told to do |
| `typical_input` | text | Recommended product |
| `typical_qty_per_ha` | numeric | Rate per hectare, scaled to the parcel in the UI |
| `unit` | text | Unit for the rate |

**Feeds:** `CropCalendarEngine`, which expands these against a real planting date
into dated tasks. This is the dataset the crop calendar cannot work without.

## 8. `barangay_suitability.csv` — where each crop actually grows well

384 rows = 48 barangays × 8 crops. Barangay was collected on every profile, farm,
and declaration and read by no engine, so every farmer in the municipality saw an
identical ranking. This is what makes location matter.

| Column | Type | Description |
|--------|------|-------------|
| `barangay` | text | One of Tubungan's 48 barangays |
| `crop_id` | text | Crop identifier |
| `terrain` | text | `lowland` / `midland` / `upland` |
| `dominant_soil` | text | Soil type driving the score |
| `yield_index` | numeric | **Observed yield ÷ attainable yield (0–1)** |
| `observations` | int | Sample size behind the figure |
| `source_year` | int | Year of observation |

**Bands** (`SuitabilityBand`, thresholds set by the adviser):

| Band | `yield_index` |
|------|---------------|
| Marginally suitable | below 0.50 |
| Moderately suitable | 0.50 – 0.69 |
| Suitable | 0.70 – 0.79 |
| Very suitable | 0.80 and above |

> **Synthetic, and the manuscript must say so.** Terrain is assigned
> deterministically (Poblacion zones are lowland; the rest are split ~28 %
> lowland / 40 % midland / 32 % upland, reflecting Tubungan's hilly interior),
> then `yield_index = terrain yield factor × the crop's affinity for that
> terrain's dominant soil`, with ±5 % deterministic variation. **Replace
> `terrains` and `terrainFor()` in the generator with the MAO's real barangay
> classification, or overwrite this CSV directly, and the whole map becomes
> real data with no code change.**

---

## How calibration is computed

`lib/data/market_dataset.dart` parses these files into a `CropCalibration` per
crop:

| Derived parameter | Formula | Feeds |
|-------------------|---------|-------|
| `baselinePricePerKg` | mean(last 12 monthly prices) | revenue, financial projection |
| `bestPriceUplift` | (P90 − mean) ÷ mean | best-case scenario |
| `worstPriceDrop` | (mean − P10) ÷ mean | worst-case scenario |
| `bestYieldUplift` | (yield_max − mean) ÷ mean | best-case scenario |
| `worstYieldDrop` | (mean − yield_min) ÷ mean | worst-case scenario |
| `priceCoefficientOfVariation` | stdev ÷ mean | volatility display |
| `totalCostPerHa` | Σ cost categories | break-even, default expenses |
| `projectedNetPerHa` | mean_yield × baseline_price − cost | recommender profit score |
| `annualDemandTons` | from demand file | saturation index |
| `landSuitability` | mean / soil-specific suitability | recommender suitability score |

If the assets fail to load on any platform, the app falls back to
`MarketDataset.fallback()` (catalog baselines) so it never fails to boot.

---

## Replacing with real MAO data

To swap in real figures from the Municipal Agriculture Office, keep the same
columns and either (a) edit `tool/generate_datasets.dart` and re-run it, or
(b) overwrite the JSON files in `assets/data/` directly. No application code
changes are required — the calibration recomputes on next launch.
