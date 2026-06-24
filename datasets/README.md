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

## 4. `demand_baselines.csv` — municipal market demand

| Column | Type | Description |
|--------|------|-------------|
| `crop_id` | text | Crop identifier |
| `annual_demand_tons` | numeric | Municipal annual demand (t) |

**Calibrates:** the denominator of the **Market Saturation Index**
(`index = expected_supply ÷ demand`).

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
