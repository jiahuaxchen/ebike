# Implementation Plan: E-bike Injury Analysis in ArcGIS Pro with GeoAI Tabular Embeddings

**Date:** 2025-10-13
**Repo context:** `jiahuaxchen/ebike`

---

## 1. What the existing R analysis does (baseline to reproduce/extend)

The repository analyzes crowdsourced bicycle-incident reports from BikeMaps.org
(US + Canada, reports after 2016-11-30; ~5,880 raw records in `code/data_raw.csv`).

| Stage | Where | What happens |
|---|---|---|
| Raw data | `data/20240425Canada.xlsx`, `data/20240425United States.xlsx`, `code/data_raw.csv` | Incident reports with point coordinates (`x`,`y`), survey attributes, free-text narrative (`details`), injury outcome |
| Exposure join | `code/preprocessing/population.Rmd`, `get_US_pop.R`, `zero_pop.R` → `data/derive/all_bike_zero.rds` | Census-block population (`pop.x`) spatially joined to each incident point (US decennial blocks; Canada equivalents); zero-pop blocks repaired |
| Age | `code/preprocessing/calculate_age.R` | `age_imp` computed from birth year/month vs. report date; binned `age_group` |
| Regrouping | `code/preprocessing/regroup_level.R` | Gender collapsed to F/M/Other; `injury2` = binary injured/not; `injury3` = ordinal A/B/C; `incident_with` lumped (vehicle / bicyclist / pedestrian / other); "don't know"-type values → NA |
| Filtering | `code/bin_logit.Rmd` | Keep `personal_involvement == "Yes"`, non-missing `ebike`; drop columns >50% missing; drop rows missing all of 5 key vars |
| Imputation | `code/bin_logit.Rmd`, `code/polr/polr.Rmd` | Bagged-tree imputation (`step_impute_bag`) → `data/derive/imputed_dataset/202408ebike_prep.rds`, `202408pedal_prep.rds` |
| Rare-level lumping | `code/bin_logit.Rmd` | Factor levels <10% of n lumped to "Other" |
| Models | `code/bin_logit.Rmd` (Bayesian `stan_glm` binary logit with `log(pop)` offset), `code/polr/polr.Rmd` (ordinal `polr`), `code/polr/random_forest/` (tidymodels ranger RF) | Separate e-bike vs. pedal-bike models; pooled model with `ebike` interactions; odds ratios + posterior intervals |
| Text | `code/text_analysis.R` | quanteda keyword co-occurrence networks on `details`, e-bike vs. pedal |

**Final modeling table** (`code/ebike_prep.csv`, n≈343 for e-bike): `incident_with, trip_purpose, helmet, road_conditions, sightlines, cars_on_roadside, bike_lights, terrain, intersection, turning, gender, pop, age_imp` → outcome `injury2`.

The ArcGIS implementation should reproduce the **injury-severity classification** and extend it with **embedding-based spatial/text context** that the R models lack.

---

## 2. Target ArcGIS tooling

Everything below lives in the **GeoAI toolbox** in ArcGIS Pro.

**Embeddings Based Analysis toolset** (new in ArcGIS Pro 3.7):

- **Generate Embeddings Using AI Models** — produces embeddings from a feature class into a BLOB field named `Embedding`. Modalities: text embeddings from an attribute field (Hugging Face *sentence-transformers* model, e.g. `all-MiniLM-L6-v2`), location embeddings, vision embeddings, multimodal.
- **Extract Embeddings To Fields** — converts the BLOB embedding into numeric columns (`emb_0 … emb_n`) usable by any standard tool (clustering, regression, AutoML).
- **Find Similar Features Using Embeddings** — nearest-neighbor similarity search over an embedding field.
- **Merge Embeddings** — concatenates multiple embeddings (e.g., text + location) per feature.

**Feature and Tabular Analysis toolset:**

- **Train Using AutoML** / **Predict Using AutoML** — tabular classification/regression; the **Use Location Embeddings** option joins Esri's **USA Geodemographic Embeddings** (256-dim vectors per H3 resolution-7 hexagon, learned from ~5,300 census/ACS/housing/environment variables) to each point as extra predictors. Basic mode produces feature-importance and SHAP reports.

**Verified availability (checked against Esri docs, 2026-10):**

- The Embeddings Based Analysis toolset is **new at Pro 3.7** (GeoAI toolbox history: Generate Embeddings Using AI Models, Extract Embedding To Fields, Find Similar Features Using Embeddings, Merge Embeddings, Predict Missing Values Using AI Model all list 3.7 as "new at this version"). None of it exists in 3.5/3.6.
- All GeoAI tools are geoprocessing tools and therefore **scriptable via `arcpy.geoai`** (e.g. `arcpy.geoai.GenerateEmbeddingsUsingAIModels(in_data, out_fc, in_model_definition_file, {arguments})`). Unconfirmed: whether the Train Using AutoML "Use Location Embeddings" checkbox has an arcpy keyword — verify with `help(arcpy.geoai.TrainUsingAutoML)` in a 3.7 install (the MVP smoke test does this).
- Pretrained models (ArcGIS AI models, June 2026 release): **HF Text Feature Extraction** (sentence-transformers text embeddings) and **Global Location Encoder (Sentinel-2)** (SatCLIP-based, coordinates → embeddings, global land coverage incl. Canada, needs ≥8 GB GPU). Both are Living Atlas .dlpk items consumed by Generate Embeddings Using AI Models.
- Output embeddings must live in a **geodatabase** (BLOB field `Embedding`); shapefiles/GeoPackage not supported.
- The "Use Location Embeddings" AutoML option is documented in the current (3.7) tool page and absent at 3.3; which encoder it uses (US-only geodemographic vs. global) is not stated — test on a Canadian point before relying on it (MVP step 6/7 settles this empirically).

**Requirements checklist (Phase 0):**

- [ ] ArcGIS Pro **3.7** (3.5+ suffices for AutoML-only work; the Embeddings toolset needs 3.7) — or an **ArcGIS Online Notebooks** Advanced-with-GPU runtime at 3.7, which removes the local-install dependency entirely (see `code/arcgis/README.md`)
- [ ] **Advanced** license (location/text embeddings); Image Analyst **not** needed (no imagery)
- [ ] **Deep Learning Libraries** installer matching the Pro version
- [ ] GPU recommended (CPU works for text embeddings at this data size: ~5,900 short narratives)
- [ ] Internet access or pre-downloaded model package for the Hugging Face text model; access to ArcGIS Living Atlas for USA Geodemographic Embeddings
- [ ] Note: USA Geodemographic Embeddings cover **CONUS + Alaska only** — Canadian incidents get no location embedding (see §6 Risks)

---

## 3. Phase 1 — Export analysis-ready data from R

Do preprocessing in R (the scripts already exist and ArcGIS cannot reproduce bagged imputation); export model-ready tables with coordinates and the narrative text.

1. New script `code/export_arcgis.R`:
   - Load `data/derive/all_bike_zero.rds`, run `calculate_age()` + `regroup()` (same as `bin_logit.Rmd`).
   - Keep: `index`, `x`, `y`, `details`, `ebike`, all model predictors, `pop`, `injury2`, `injury3`.
   - Join the **imputed** values from `202408ebike_prep.rds` / `202408pedal_prep.rds` back by `index` so ArcGIS models train on the same imputed data as the R models. Also export a non-imputed version (AutoML can handle NAs internally) for a sensitivity check.
   - Add `log_pop = log(pmax(pop,1))`.
   - Write `data/derive/arcgis/incidents_ebike.csv`, `incidents_pedal.csv`, `incidents_all.csv` (comma-separated, UTF-8, no factor codes — plain labels).
2. In ArcGIS Pro: **XY Table To Point** (x = longitude, y = latitude, GCS WGS 1984 — verify against the source; BikeMaps exports are WGS84) → file geodatabase feature classes `incidents_ebike`, `incidents_pedal`, `incidents_all`.
3. QA: record counts match R (`ebike` n≈343 after filtering), no null geometries, outcome distribution matches `summary(ebike_prep)`.

---

## 4. Phase 2 — Generate embeddings

### 2a. Text embeddings of the incident narrative (`details`)

This is the main new capability over the R analysis (which only did keyword co-occurrence).

- Tool: **Generate Embeddings Using AI Models**
  - Input: `incidents_all`; text field: `details`
  - Model: Hugging Face `sentence-transformers/all-MiniLM-L6-v2` (384-dim; small, CPU-friendly). Alternative: `all-mpnet-base-v2` (768-dim) if quality matters more than speed.
  - Output: `incidents_all_textemb` with BLOB `Embedding` field.
- Rows with empty `details` will produce degenerate embeddings — flag them with a `has_details` field first and exclude from text-embedding analyses.

### 2b. Location embeddings (US points)

- Easiest path: in **Train Using AutoML**, enable **Use Location Embeddings** — Pro joins the USA Geodemographic Embeddings (256 dims) automatically.
- For standalone exploration: add the **USA Geodemographic Embeddings** Living Atlas layer, spatial-join the H3 hexagon vector to incident points.
- Canadian points: no coverage. Either (a) run location-embedding models on the US subset only, or (b) substitute Canadian census profile variables joined manually as plain predictors (documented limitation, not an embedding).

### 2c. Flatten and combine

- **Extract Embeddings To Fields** on the text-embedding feature class → numeric `emb_*` columns.
- Optionally **Merge Embeddings** to concatenate text + location embeddings for the US subset.

---

## 5. Phase 3 — Models (Train Using AutoML)

Target: `injury2` (binary classification). Run each configuration for **e-bike** and **pedal** subsets separately (mirrors the R design), plus a pooled run with `ebike` as a predictor.

| Run | Predictors | Purpose |
|---|---|---|
| A (baseline) | The 13 tabular survey fields + `log_pop` | Parity with the R `stan_glm` predictor set |
| B | A + location embeddings (Use Location Embeddings; US subset) | Does geodemographic context add signal? |
| C | A + text-embedding fields (`emb_*` from `details`) | Does the narrative add signal? |
| D | A + both (merged embeddings; US subset) | Full model |

Settings:

- **Basic mode** (enables feature-importance / SHAP reports — use these to compare against R odds-ratio directions).
- Evaluation metric: **AUC** (also record log-loss and accuracy); hold out a stratified ~20% test set *before* training and score it with **Predict Using AutoML** — don't rely only on AutoML's internal validation.
- Keep the same random seed and the same holdout rows across runs A–D so metrics are comparable.
- **Exposure offset caveat:** AutoML has no `offset(log(pop))` equivalent. Including `log_pop` as a plain predictor is the pragmatic substitute, but coefficients are then *learned*, not fixed at 1 — note this when comparing with the Bayesian logit. For pure injury-severity classification (injured vs. not, conditional on an incident happening), the offset arguably isn't needed at all; decide and document which framing you're using.
- **Class imbalance:** check injury2 balance per subset; if skewed, prefer AUC/F1 over accuracy (the R RF used upsampling; AutoML algorithms handle imbalance via internal validation, but report the confusion matrix on the holdout).
- **Geography of the e-bike subset (measured 2025-10-13):** after the study-period filter the source files hold 395 Canadian vs. 89 US e-bike reports (376 vs. 77 after the `personal_involvement == "Yes"` filter) — **~83% of e-bike cases are Canadian**. Consequences:
  - Run B/D with USA Geodemographic Embeddings is **not viable as a standalone e-bike model** (n≈77). Use those embeddings only for the pedal/all-bike US models, or for the pooled model restricted to US rows.
  - For geography-aware e-bike modeling, prefer (i) the **Global Location Encoder (Sentinel-2)** pretrained location-embedding model (global coverage, works for Canada) via Generate Embeddings Using AI Models, or (ii) a manual join of Statistics Canada census-profile variables (the repo already has `data/CanadaPop/`) as plain covariates.
  - **Text embeddings (run C) are geography-agnostic** and remain the primary embedding track for the e-bike analysis.
- **Overfitting control (small n vs. embedding width):** the pretrained encoders are frozen, so the risk lives entirely in the downstream classifier. Reduce the extracted text-embedding fields with **PCA to ~20–50 components** before AutoML (keep the PCA fitted on training folds only); prefer the pooled model (n≈2–3k) with an `ebike` flag over the e-bike-only model when embeddings are included; judge embedding lift on repeated train/test splits, not a single holdout, since one 20% holdout of 343 rows (~69 cases) gives AUC estimates with wide uncertainty.

---

## 6. Phase 4 — Embedding-based exploration (beyond the R analysis)

1. **Incident typologies:** Multivariate Clustering (or HDBSCAN via Density-based Clustering) on the extracted text-embedding fields → cluster labels = narrative incident types ("dooring", "right-hook", "coal-rolling harassment", …). Cross-tab clusters × `injury2` × `ebike`; map clusters. This supersedes the quanteda co-occurrence networks in `code/text_analysis.R`.
2. **Similarity search:** **Find Similar Features Using Embeddings** seeded with hospitalized-injury (injury3 = C) e-bike incidents → retrieve narratively similar near-misses (candidate "almost-severe" events worth qualitative review).
3. **SHAP interpretation:** from run D's report, identify which embedding dimensions matter, then use Find Similar / cluster membership to give those dimensions a qualitative reading (dimensions are latent, not directly interpretable).

---

## 7. Phase 5 — Validation against the R results

- Compare holdout AUC of run A against the R models (compute AUC for `stan_glm`/RF on the same holdout rows in R for a fair comparison).
- Check that SHAP/feature-importance directions for helmet, intersection, cars_on_roadside, terrain(downhill), gender, age agree in sign with the posterior intervals in `bin_logit.Rmd`; investigate disagreements.
- Report deltas B−A, C−A, D−A (embedding lift) with the caveat that B and D are US-only.

---

## 8. Deliverables

1. `code/export_arcgis.R` + exported CSVs in `data/derive/arcgis/`
2. ArcGIS Pro project (`.aprx`) with: incident feature classes, embedding feature classes, trained AutoML models (`.dlpk`), AutoML reports
3. Comparison memo: R vs. ArcGIS metrics, SHAP vs. odds ratios, embedding lift
4. Maps: incident typology clusters, predicted-probability surfaces

## 9. Risks and open questions

| Risk | Mitigation |
|---|---|
| USA Geodemographic Embeddings exclude Canada — **~83% of e-bike cases (376/453) are Canadian**, so a US-only e-bike location-embedding model has n≈77 | Use geodemographic embeddings only for pedal/all-bike US models; for e-bike geography use the Global Location Encoder (Sentinel-2) pretrained model (global) or StatCan census joins; lean on text embeddings as the main e-bike track |
| Small n (e-bike ≈ 343) vs. 384–640 embedding dims → overfitting | Rely on AutoML internal CV + strict external holdout; consider PCA on extracted embedding fields (keep ~20–50 components) before training |
| Pro 3.7 / Advanced license / DL libraries availability | Verify in Phase 0 before committing; AutoML-only fallback works on 3.5+ |
| No offset term in AutoML | `log_pop` as predictor + documented framing decision (§5) |
| `details` quality varies; witness reports filtered out in R pipeline | Keep the `personal_involvement == "Yes"` filter for parity; `has_details` flag |
| Coordinate reference mismatch | Confirm source CRS before XY Table To Point; spot-check against `output/map/study_area.jpg` |

## 10. Suggested order of work

1. Phase 0 checklist (half day)
2. Phase 1 export + feature classes (1 day)
3. Run A baselines, validate against R (1 day)
4. Phase 2 embeddings + runs B–D (1–2 days)
5. Phase 4 exploration + Phase 5 comparison memo (2 days)
