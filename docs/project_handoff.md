# Project Handoff: BikeMaps GeoAI Embedding Analysis

Self-contained summary of the work and decisions to date (2026-10-19). Written to
transfer into a new conversation about the GGA module research design; also the
factual basis for a later paper. Repo: `jiahuaxchen/ebike`, branch
`claude/wonderful-cerf-a9rbub`.

## 1. Data

- **Source:** BikeMaps.org crowdsourced bike incident reports (collisions +
  near-misses), pulled via a Colab/osmnx extractor. The full-feed endpoint now
  returns 502; data must be pulled in **bbox tiles** (per province/state — the
  extractor was fixed to loop 48 mainland US states + DC, mirroring the Canada
  province loop; `drop_duplicates(subset='pk')` guards tile seams).
- **Fresh pulls (2026-10):** US mainland 2,059 reports (153 e-bike); Canada
  re-pulled the same way. Analyzed corpus after filters: **4,397 narratives,
  ~17.5% e-bike (~770)**.
- **Filters (fixed):** date > 2016-11-30 and ≤ today (one report is dated 2916 —
  clamp), `personal_involvement == "Yes"` (so demographics describe the rider),
  `ebike` in {Yes, No}, narrative ≥ 20 chars, non-French (French ≈ 1.2%, detected
  by French-stopword heuristic — an English-stopword test false-flags terse
  English narratives; do NOT use it).
- **Known data facts:** injury share of reports declined ~26% (2017) → ~14%
  (2025) as near-miss reporting grew — a critical confounder for any subgroup
  comparison. `age` column is **birth year**, not age (compute age at incident =
  report year − birth year; ~37% missing, equally across bike types).
  `ebike_class` only ~10% complete corpus-wide — class-gradient analysis dropped.
  No reporter ID (dedup by unique report-days where needed). No exposure
  denominator exists — crash *rates* are unanswerable, ever.

## 2. Leakage control (applies to all text analysis)

Measured: 30% of injured riders' narratives contain outcome words vs 5.9% of
uninjured; P(injured | outcome word) = 51% vs 17% base. **Mask before embedding**:
delete every sentence matching the frozen lexicon (injur*, hospital*, doctor,
ambulance, paramedic, brok*, fractur*, pain*, bruis*, stitch*, concuss*,
emergency, x-ray, sprain*, bleed*, blood, scrape*, road rash, wound*, surgery,
clinic, ER). Event words (hit, fell, collided) are kept deliberately — mechanism,
not outcome. Masking matters MOST when validating clusters against injury rates
(otherwise circular).

## 3. Tooling facts (verified on ArcGIS Pro 3.7.1, Advanced license, CPU-only machine)

- The **Embeddings Based Analysis toolset is new at Pro 3.7**: Generate Embeddings
  Using AI Models, Extract Embedding To Fields, Find Similar Features Using
  Embeddings, Merge Embeddings. All scriptable via `arcpy.geoai`. Verified
  signatures: `ExtractEmbeddingToFields(in, out, "Embedding", "emb")`;
  `FindSimilarFeaturesUsingEmbeddings(embedding_fc, query_fc, out, threshold 0-1)`
  (query features cannot be `in_memory`).
- **Text model:** HF Text Feature Extraction dlpk (sentence-transformers
  `all-MiniLM-L6-v2`, 384-d), runs fine on CPU. English-centric.
- **Location models:** (a) USA Geodemographic Embeddings — 256-d per H3 res-7 hex,
  built from ~5,300 Census/ACS/housing variables + environmental rasters
  (nighttime lights, climate, land cover, noise, PM2.5). **US-only. Contains NO
  OSM/POI/street-network content** — it knows who lives nearby, not how streets
  are built. (b) Global Location Encoder (Sentinel-2) — SatCLIP-based,
  coordinates→256-d, global land coverage, smooth/coarse (≈ land-use context, no
  street-level variance within a metro). Its dlpk **hard-codes `.cuda()`** and
  crashes on CPU — we patch the extracted dlpk (`.cuda()`→`.cpu()`) and run the
  `.emd`; filed-worthy Esri product bug. Our machine: Intel UHD 770, no CUDA
  possible; AGOL Notebooks "Advanced with GPU" is the fallback for GPU-bound steps.
- Spatial concentration: US reports sit in ~666 2-km cells; 22% in the top 10 —
  geodemographic vectors partially encode "which city" (demands a city-fixed-effect
  sensitivity check in any model using them).
- Working pipeline notebook: `code/arcgis/gga_typology_module.ipynb` (resumable
  steps with progress.json; CSV→points→embed→extract→cluster→validate). Smoke
  test: `code/arcgis/mvp_geoai_smoke_test.py` (all 7 capabilities pass).

## 4. Executed results

**Typologies (pooled US+Canada, masked text, n=4,397).** HDBSCAN finds 100% noise
at any n — the narrative embedding space is a **continuum**, typologies cannot be
density-discovered. Adaptation: KMeans k=14 (over-segment), read, **merge by hand
into 7 typologies**: contact/crash (n=828, 32.0% injured), didn't-see-me (348,
21.6%), unsafe/close pass (1,055, 18.4%), failed yield (907, 15.4%),
harassment (411, 13.9%), infrastructure complaints (505, 13.9%), signal
violations (343, 11.1%). Injury × typology χ²=129, p≈2e-25 (top of gradient is
near-tautological: contact > near-miss; informative part is the conflict-type
ordering and the harassment category, which no official form records).

**E-bike composition: NULL.** E-bike share flat (15.5–19.0%) across typologies,
χ²=2.4, p=0.88, well-powered. E-bikes experience the same mechanism mix.

**E-bike severity: NULL after adjustment.** Crude: e-bike reports less often
injury reports (severe-injury 6.5% vs 10.7%, p=0.0004) — **explained as a
report-year artifact** (e-bike reports are recent; injury share fell 26%→14%;
e-bike reports modestly more near-miss-heavy, 77% vs 72%). Adjusted (typology +
age + year): **OR = 0.90 (95% CI 0.69–1.18), n=2,787**. Given a collision:
injury 68.8% (e-bike) vs 67.2% (pedal) — identical. Age is a non-confounder here
(mean 40.8 vs 40.1). Converges with the prior R ordinal model (OR 0.90,
0.60–1.42). The earlier "harassment protective" cell (p=0.009) is treated as
spurious (7 tests + era artifact).

**Twin-matching analyses (executed 2026-10-19/20; results in notebook + chat
only — not yet written into the experiment plan).** Matched each e-bike report
to its best pedal counterpart, always same country + report year ±1, without
replacement, randomized tie-breaks:
- **Embedding twins** (match on masked-narrative cosine; 523 unique pairs,
  median similarity 0.81; top pairs are visibly "the same story"): −1.9pp,
  McNemar p=0.40 — null. (With replacement it was −3.6pp p=0.048 — shown to be
  inflated by twin reuse, max 13×: a methods lesson, not a finding.)
- **Field twins v2** (hard match on full-level `incident_with`; soft agreement
  score over intersection, turning, terrain, road_conditions, cars_on_roadside,
  sightlines, helmet, trip_purpose, gender, age±10; 763 pairs, median agreement
  0.9): −4.0pp, p=0.042 — shown to carry **near-miss-mix leakage** (fields can't
  see event resolution; e-bike reports are more near-miss-heavy).
- **Field twins v3** (adds `p_type` collision/near-miss to the hard match —
  estimand becomes "same circumstances AND same event resolution"): ordinal
  injury ladder (0 none / 1 untreated / 2 medical care) within 747 pairs —
  **null everywhere**: all pairs mean 0.222 vs 0.245 (sign p=0.32, direction
  twin-worse); collision pairs 0.98 vs 1.04 (p=0.63); **both-injured pairs
  (severity|injury, the hospital-literature conditioning): 1.44 vs 1.51, p=0.44,
  n=82 (limited power — phrase as "no evidence of", not "evidence of no")**.
- Pattern across designs: the apparent protection shrinks monotonically as the
  match sees more of the event (coarse fields −3.4pp → fine fields −4.0pp with
  mix leakage → narrative −1.9pp → p_type-matched ordinal ≈ 0). This gradient
  itself quantifies that injury-relevant event information lives in the
  narrative beyond ten well-chosen survey fields ("the value is in the text").

**FINAL FINDING (one paragraph, fully triangulated):** In ~4,400 rider-reported
incidents, e-bike and pedal riders experience the same mix of incident
mechanisms, and matched comparisons — on circumstances, on event type, and on
the narrative itself — show no difference in injury occurrence or severity,
including among pairs where both riders were injured. The apparently lower
injury share in e-bike reports is fully explained by reporting era. Limits:
no exposure denominator; outcomes conditional on the decision to report;
limited power in the severity-given-injury stratum.

**Three demonstrated methods lessons (paper paragraphs / module exercises):**
(1) report-year confounding in crowdsourced subgroup comparisons (26%→14%
injury-share decline); (2) reused-control inflation in with-replacement
matching (p=0.048 → 0.40 without replacement); (3) outcome-mix leakage in
field-based matching (−4.0pp → null once event resolution is matched).

**Prior work this corrects/extends (from the research log):** the 2025 text
co-occurrence impression "e-bike ≈ intersection-related" is not supported once a
pedal baseline is used (composition null). Separate e-bike/pedal regressions
showing "different predictors" may be a power artifact (interactions were not
significant) — testable via embedding transfer (below).

## 5. Strategic decision: two deliverables, one shared backbone

Trying to make one analysis serve both degrades both. Shared: data pulls,
cleaning/masking, embeddings, typologies, harness. Separate narratives:

**(A) GGA educational module — anchor on the tools; the caveats ARE the
curriculum.** Three acts:
1. Text embeddings: narratives → typologies → injury gradient; teach leakage
   (51%-vs-17%) and the continuum finding (HDBSCAN noise → overcluster+merge).
2. Location embeddings: A/C/G/CG ablation (A=survey fields, C=+text 384-d,
   G=+geodemographic 256-d, CG=both; identical rows, 20 repeated stratified
   splits, per-fold PCA, paired ΔAUC ≥ 0.02 rule) — **capstone exercise: add a
   city fixed effect to the baseline and watch G's lift shrink** → teaches scale
   confounding / what location embeddings actually encode.
3. Closing lesson: what each embedding knows vs. doesn't (no street-level
   content); the fix for the gap is classic GIS — an OSM join. US-only cohort for
   the ablation: n≈1,563 masked narratives.
Module framing: "embeddings are powerful, and here is how to interrogate them."

**(B) Paper — anchor on the findings; embeddings as instruments.** Story: e-bike
incidents show the same mechanism mix and no adjusted excess injury risk; the
crude protective signal is a report-year artifact (a general methods warning for
crowdsourced subgroup comparisons). Methods roles for embeddings: typology
construction; **scaling the existing NVivo codebook** (627 hand-coded e-bike
narratives from prior qualitative work = training labels → classifier → code the
full corpus incl. pedal baseline → per-code prevalence comparison; the strongest
remaining analysis); narrative-twin matching (nearest pedal narrative per e-bike
narrative, paired outcome comparison) as sensitivity; discriminative probe
(ebike-vs-pedal classifier on masked embeddings; AUC≈0.5 confirms composition
null at every grain; guard year/region confounds). OSM covariates (cycleway,
road class, junction distance via osmnx) as infrastructure variables; recover the
badly-missing `intersection` survey variable from text + OSM geometry. Location
embeddings: not in the paper. Targets: AAP / J. Transport & Health; the
report-year artifact possibly a standalone methods note.

**Sequencing:** module first (≈80% built), paper second.

## 6. Remaining work

**The analysis phase is done** (as of 2026-10-20); what remains is assembly.
Module: ablation lab (Study 3 design in `docs/text_embedding_experiment_plan.md`),
geodemographic H3 join, closing-lesson materials, cluster naming answer key,
typology map, k=14 bootstrap stability check, `p_type` validity cross-tab; the
field-twins-vs-embedding-twins contrast is a ready-made capstone exercise.
Paper: record the twins/ordinal series in the experiment plan's results section
(not yet done); NVivo-codebook scaling (627 hand-coded e-bike narratives as
training labels — strongest remaining analysis); transfer test; discriminative
probe; OSM covariates + intersection-variable recovery; write-up. Manager brief
(Claude doc) pre-dates all results and needs a full refresh before reuse.

## 7. Key documents in the repo (branch `claude/wonderful-cerf-a9rbub`)

- `docs/arcgis_geoai_implementation_plan.md` — original tool/plan survey.
- `docs/text_embedding_experiment_plan.md` — pre-registered designs + executed
  results (source of truth for numbers).
- `docs/nearmiss_site_prioritization_study.md` — separate study design: near-miss
  site ranking with mechanism profiles + temporal validation (untouched, future).
- `code/arcgis/` — smoke test, MVP sample, module notebook.
- Manager brief (Claude doc): https://claude.ai/artifact/SsFDSZv3r8y9JMZpSqF6Yd
  (pre-dates the results; needs updating with §4 before reuse).
- Research log (Google Doc "Ebike-Steps") — NVivo node structure (2025/6/10) maps
  ~1:1 onto the discovered typologies; the 627 coded narratives are the training
  labels for codebook scaling.
