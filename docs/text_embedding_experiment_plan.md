# Experiment Plan: Does Narrative Text Add Signal? (A vs C) + Incident Typologies

**Scope:** two concrete studies on the BikeMaps data using the ArcGIS Pro 3.7 GeoAI
tools validated by the smoke test (`code/arcgis/`). Study 1 measures whether text
embeddings improve injury prediction over the survey fields. Study 2 clusters the
narratives into nameable incident typologies and converts them into regression-ready
variables. Decisions are pre-registered here so results can't be cherry-picked later.

---

## Study 1 — A vs C: survey fields vs. survey + text embeddings

### Question
How much injury-relevant information do the narratives contain beyond the 13
structured survey fields — after removing outcome leakage?

### Cohort (fixed before any modeling)
- All incidents with `personal_involvement == "Yes"`, known `ebike`, non-missing
  `injury2`, and a narrative of ≥ 20 characters.
- **Primary analysis: pooled** (pedal + e-bike, `ebike` as a predictor; n in the
  low thousands). **Secondary: e-bike only** (n ≈ 450) — reported with wider
  uncertainty, never alone.
- Survey predictors: the imputed set used in `bin_logit.Rmd`
  (incident_with, trip_purpose, helmet, road_conditions, sightlines,
  cars_on_roadside, bike_lights, terrain, intersection, turning, gender, age_imp)
  plus `log_pop` and `ebike`.

### Leakage control (the masked-text variant is the primary input)
Measured fact motivating this: 30% of injured riders' narratives contain outcome
vocabulary vs 5.9% of non-injured; P(injured | outcome word) = 51% vs a 17% base rate.
- Build `details_masked` in the R export script: delete every sentence matching the
  outcome lexicon `injur*, hospital*, doctor, ambulance, paramedic, brok*, fractur*,
  pain*, bruis*, stitch*, concuss*, emergency, x-ray, sprain*, bleed*, blood,
  scrape*, road rash, wound*, surgery, clinic, ER` (case-insensitive; extend the
  list by reading 50 random injured narratives before freezing it).
- Narratives emptied by masking leave the cohort fixed: keep the row, embed the
  empty string replaced by the single token "no description" (and carry a
  `was_masked_empty` flag as a predictor in C so the model can use "said nothing
  after masking" honestly).

### Conditions (same rows, same splits, everywhere)
| Run | Predictors | Purpose |
|---|---|---|
| A | survey fields | baseline |
| C | A + embeddings of `details_masked` | the headline comparison |
| C_raw | A + embeddings of raw `details` | quantifies leakage: C_raw − C |
| T | embeddings of `details_masked` alone | how much text alone carries |

### Pipeline (per condition)
1. R: `code/export_arcgis.R` writes one CSV (id, outcome, survey fields,
   details, details_masked, x, y).
2. ArcGIS (arcpy, scripted once): XY Table To Point → Generate Embeddings Using
   AI Models (HF Text Feature Extraction, 384-dim) on the relevant text column →
   Extract Embedding To Fields → export table with `emb_*` columns.
3. Evaluation harness (Python notebook in Pro; sklearn ships in arcgispro-py3):
   - **20 repeated stratified 80/20 splits**, seeds 1–20, identical across all
     conditions (split on the id list once, reuse).
   - Within each training fold: PCA on the embedding columns to **50 components**
     (fit on train only, applied to test); survey fields one-hot encoded.
   - Two learners per condition, reported separately: penalized logistic
     regression (L2, class-weighted) and gradient boosting (LightGBM or sklearn
     HistGB, default + light tuning on train folds only).
   - Metrics: **AUC (primary)**, PR-AUC, Brier score, calibration slope.
4. One **Train Using AutoML (Basic)** run per condition on split seed 1 — the
   in-product demonstration and the SHAP report for run A — but the inference
   about text signal comes from the 20-split harness, not from AutoML's internal
   validation.

### Decision rule (pre-registered)
- Compute ΔAUC = AUC(C) − AUC(A) per split; report mean, 95% CI over the 20
  paired splits.
- **Text adds signal** if the CI excludes 0 **and** mean ΔAUC ≥ 0.02.
- Leakage is reported regardless: mean AUC(C_raw) − AUC(C).
- If C beats A: proceed to Study 2's factor-conversion step with priority.
  If not: report that the 13 survey fields already capture the narratives'
  predictive content — a finding, not a failure — and Study 2 still proceeds
  for discovery purposes.

### Effort
~1 day R export + embedding generation; ~1 day harness + runs; ~0.5 day write-up.

---

## Study 2 — Typology discovery and conversion to named factors

### Question
What kinds of incidents exist in the narratives that the survey form doesn't ask
about, and do any of them carry distinct injury risk?

### Clustering protocol
1. Input: masked-text embeddings (same as Study 1) for the **pooled** cohort —
   more narratives give cleaner clusters; `ebike` is an attribute, not a filter.
2. L2-normalize embeddings. Primary method: **HDBSCAN** (sklearn ≥1.3;
   `min_cluster_size = 30`) on a 15-component PCA; it finds the number of
   clusters itself and leaves genuinely odd narratives unclustered (label −1)
   instead of forcing them. Fallback/in-product demo: ArcGIS **Multivariate
   Clustering** (k-means) on the PCA fields, k chosen by its pseudo-F statistic,
   k ∈ 5…15.
3. Stability check: re-run HDBSCAN on 10 bootstrap resamples; report the
   adjusted Rand index between runs. Clusters that dissolve under resampling
   are not reported as typologies.

### Naming (the human-in-the-loop step)
For each stable cluster: top-15 TF-IDF terms vs. the rest of the corpus, the 5
narratives nearest the cluster center, and 15 random members. Read them; write a
one-line definition ("right-hook by turning vehicle at signalized intersection").
A cluster that can't be named coherently is reported as unnamed, not forced.

### Validation and use
- Injury rate per typology with 95% CIs; e-bike share per typology; both tested
  (chi-square) against the pooled rates. A map of incidents colored by typology
  (this is the headline graphic for the manager).
- **Conversion to named factors:** for the 2–4 typologies that are actionable
  and risk-distinct, build a per-incident binary flag — keyword rules first, a
  small text classifier (ArcGIS Train Text Classification Model) if rules are
  too crude. Hand-label 100 random incidents to measure each flag's
  precision/recall before trusting it.
- **The inferential payoff:** add the validated flags to the existing Bayesian
  logistic model next to helmet/terrain/etc. The flags get odds ratios and
  credible intervals; the embeddings themselves never appear in the final model.
  This is the step that turns "the text contains signal" into "dooring incidents
  carry 2.3× the injury odds."

### Effort
~1 day clustering + stability; ~1 day reading/naming + flags; ~0.5 day
regression update and write-up. Independent of Study 1's outcome; shares its
embedding generation.

---

## Shared practicalities
- Everything after the R export runs in one ArcGIS Pro notebook; the GeoAI steps
  are the ones already validated in `code/arcgis/mvp_geoai_smoke_test.py`.
- Text model pinned: `all-MiniLM-L6-v2` (384-dim) for both studies; note the
  model name and dlpk version in the write-up for reproducibility.
- Random seeds fixed and logged (splits: 1–20; clustering: 1208).
- One combined report at the end: ΔAUC table, leakage number, typology table
  with injury rates, the map, and the updated odds-ratio plot.
