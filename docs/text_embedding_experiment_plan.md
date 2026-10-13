# Experiment Plan: Incident Typologies (US+Canada) + Injury Prediction with Embeddings (US)

**Scope (revised 2026-10 after the MVP run and fresh data pulls):** two studies with
deliberately different geographies, because the embedding families have different
coverage. **Study 1 (typology)** clusters masked narratives on the **pooled
US+Canada** corpus — the biggest sample, and the only route to e-bike conclusions
(e-bike-only clustering fails at n≈150–450: the 400-row MVP had silhouettes ≈0.10
and HDBSCAN returned 100% noise). **Study 2 (prediction)** is **US-only**, because
the USA Geodemographic Embeddings cover only the US; it tests text and
census-context embeddings in an ablation (A/C/G/CG). One embedding family per
question; the Sentinel-2 location encoder is dropped for US-only work (strictly
dominated by the census embeddings there) and remains only as the Canada substitute
if cross-border geography is ever needed. Decisions are pre-registered here so
results can't be cherry-picked later.

**Data: the fresh 2026-10 pulls** (US: 2,059 mainland reports, 153 e-bike; Canada:
rerun of the state/province-tiled extractor). Cleaning additions since the first
draft:

- Clamp dates to ≤ today (one US report is dated 2916).
- Filter non-English narratives (MiniLM is English-centric; the MVP found French
  reports polluting clusters): keep rows where ≥2 of {the, and, was, with, to}
  appear, or use a langdetect pass.

**Shared leakage control (both studies use the masked text).** Measured fact: 30%
of injured riders' narratives contain outcome vocabulary vs 5.9% of non-injured;
P(injured | outcome word) = 51% vs a 17% base rate. `details_masked` deletes every
sentence matching the frozen lexicon `injur*, hospital*, doctor, ambulance,
paramedic, brok*, fractur*, pain*, bruis*, stitch*, concuss*, emergency, x-ray,
sprain*, bleed*, blood, scrape*, road rash, wound*, surgery, clinic, ER`
(case-insensitive; extend only by reading narratives, never from cluster or model
results). Masking matters even more in Study 1 than Study 2: the typologies are
validated against injury rates, so unmasked text would let clusters form around
outcome descriptions and make that validation circular.

---

## Study 1 — Incident typologies (pooled US+Canada, masked text)

### Question
What nameable incident mechanisms exist in the narratives, do they carry different
injury risk, and how do e-bike incidents differ in mechanism mix and
severity-within-mechanism?

### Cohort
All incidents (US+Canada) with `personal_involvement == "Yes"`, known `ebike`,
non-missing injury outcome, and an English narrative ≥ 20 characters surviving
masking. Expected n ≈ 3,800+ on the fresh pulls; e-bike ≈ 550+.

### Protocol (implemented in `code/arcgis/gga_typology_module.ipynb`)
1. Embed masked narratives (HF Text Feature Extraction, 384-dim, CPU-validated).
2. L2-normalize → PCA(15) → **HDBSCAN, min_cluster_size = 30** (KMeans
   silhouette-sweep fallback is wired in but at this n HDBSCAN should hold).
3. Stability: 10 bootstrap resamples, adjusted Rand index; clusters that dissolve
   are not reported as typologies.
4. Naming: top TF-IDF terms + 5 center-nearest + 15 random narratives per cluster;
   a cluster that can't be named coherently is reported unnamed.
5. Validation: injury rate per typology with Wilson CIs, chi-square; map colored
   by typology.
6. **E-bike inference (projection, never e-bike-only clustering):**
   - Composition: typology × ebike chi-square ("e-bikes over-represented in X").
   - Severity within typology: injury rate e-bike vs pedal *inside* each typology
     (controls for mechanism mix).
   - Hypothesized e-bike-specific mechanisms (driver misjudges speed, heavy-bike
     low-speed falls, throttle starts): targeted similarity search from seed
     sentences, reported qualitatively — not clustering.
7. Conversion to named factors: for 2–4 risk-distinct typologies, binary flags
   (keyword rules or a small text classifier), validated on 100 hand-labeled
   incidents, then entered into the logistic model next to the survey fields for
   odds ratios. Embeddings never appear in the final inferential model.

### Effort
~1 day embedding + clustering on fresh data (module notebook is ready); ~1 day
naming + validation + e-bike projection; ~0.5 day flags + regression.

---

## Study 2 — Injury prediction ablation (US only, AutoML)

### Question
Beyond the survey fields, how much predictive signal do (a) the narratives and
(b) census geodemographic context each add — and do they overlap?

### Cohort
US mainland reports, post-2016-11-30, `personal_involvement == "Yes"`, known
`ebike`, usable masked narrative (n ≈ 1,563 on the fresh pull — all bike types,
`ebike` as a predictor flag). **No e-bike-only model** (n ≈ 150 is below any
defensible threshold); e-bike results are descriptive only.

### Conditions (identical rows and splits everywhere)
| Run | Predictors | Purpose |
|---|---|---|
| A | survey fields (+ `ebike`, `log_pop`) | baseline |
| C | A + masked-text embeddings (384d) | narrative signal |
| G | A + USA Geodemographic Embeddings (256d, H3 res-7 join) | census-context signal |
| CG | A + both | overlap vs complement |

Optional: C_raw (raw-text embeddings) to quantify leakage, as in the first draft.

### Pipeline
1. Text embeddings: same Generate Embeddings → Extract To Fields chain as Study 1
   (reuse the Study 1 vectors for the US subset — one embedding pass serves both
   studies).
2. Geodemographic embeddings: explicit spatial join of incident points to the USA
   Geodemographic Embeddings H3 layer (Living Atlas) so that all conditions run
   through one identical harness. The AutoML **Use Location Embeddings** checkbox
   is run once as the in-product demonstration, not as the measured condition.
3. Evaluation harness (sklearn in the Pro notebook): **20 repeated stratified
   80/20 splits**, seeds 1–20, identical across conditions; PCA fit on training
   folds only (≈50 components for text, ≈30 for geodemographic); penalized
   logistic + gradient boosting, reported separately; metrics AUC (primary),
   PR-AUC, Brier, calibration slope.
4. One Train Using AutoML (Basic) run per condition on split seed 1 for the SHAP
   report and product demo.

### Decision rules (pre-registered)
- ΔAUC per split (paired), mean + 95% CI over 20 splits; "adds signal" = CI
  excludes 0 AND mean ΔAUC ≥ 0.02. Applied to C−A, G−A, CG−A, and CG−C (does
  geography add anything once text is in?).
- **Metro-identity sensitivity check:** 22% of US reports sit in 10 ~2-km cells,
  so the geodemographic vectors partially encode "which city." Re-run A with a
  city/region fixed effect added; if G's lift over that augmented baseline
  vanishes, report G as proxying metro identity rather than neighborhood context.
- Leakage (if C_raw is run): mean AUC(C_raw) − AUC(C), reported regardless.

### Effort
~0.5 day geodemographic join; ~1 day harness + runs (text vectors reused);
~0.5 day write-up.

---

## Shared practicalities
- Text model pinned: `all-MiniLM-L6-v2` (384-dim) via the HF Text Feature
  Extraction dlpk; note dlpk version in write-ups.
- Seeds fixed: splits 1–20; clustering 1208.
- Both studies run inside ArcGIS Pro notebooks on CPU; the geodemographic join
  needs the Living Atlas layer (sign-in), nothing else is new.
- Combined report: typology table + map + e-bike projection (Study 1); ΔAUC
  ablation table + SHAP for run A (Study 2); leakage and metro-identity
  sensitivity results as appendices.
