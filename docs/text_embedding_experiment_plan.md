# Experiment Plan: Typologies, E-bike Severity, and Embedding Ablation

**Status (2026-10-19):** Study 1 (typology) has been executed on the full corpus —
its results are recorded below and feed Study 2. **Study 2 (e-bike severity) is now
the centerpiece**: the answerable, policy-relevant e-bike question, designed around
the estimand rather than the tooling. Study 3 (US-only prediction ablation) is the
Esri-facing methods demonstration. Decisions are pre-registered; executed parts are
marked with their actual results.

**The estimand discipline (drives everything):** there are three e-bike questions.
*Do e-bikes crash more?* — unanswerable here (no exposure denominator); nothing may
imply it. *Do e-bikes crash differently?* — answered by Study 1: **no** (composition
null, below). *Given the same crash, does an e-bike end worse?* — answerable, and
Study 2's subject.

**Data:** fresh 2026-10 pulls via the state/province-tiled extractor (full-feed
endpoint 502s). Cleaning: date clamp (≤ today), French-narrative drop (~1.2%,
detected by French-stopword heuristic — an English-stopword test false-flags terse
English), outcome-word masking (lexicon below). Analyzed corpus: **4,397 masked
English narratives, ~17.5% e-bike (~770)**.

**Leakage control (both text studies).** Measured: 30% of injured riders' narratives
contain outcome vocabulary vs 5.9% of non-injured (P(injured | outcome word) = 51%
vs 17% base). `details_masked` deletes every sentence matching the frozen lexicon
`injur*, hospital*, doctor, ambulance, paramedic, brok*, fractur*, pain*, bruis*,
stitch*, concuss*, emergency, x-ray, sprain*, bleed*, blood, scrape*, road rash,
wound*, surgery, clinic, ER`. Event words (hit, fell, collided) are deliberately
kept: they describe mechanism, not outcome.

---

## Study 1 — Incident typologies (pooled US+Canada) — EXECUTED

### Method as run
Masked narratives → MiniLM 384-d embeddings (CPU) → L2-norm → PCA(15). **Finding:
the embedding space is a continuum** — HDBSCAN returns 100% noise at n=4,397, so
typologies cannot be "discovered" as density clusters. Protocol adapted:
**over-segment with KMeans k=14** (silhouette-chosen k=4 blends mechanisms), read
every cluster (TF-IDF terms + samples), **merge by hand into 7 nameable
typologies**. This adaptation is a finding in itself and is reported as such.

### Results (2026-10-19 run)
| Typology | n | Injury rate (95% CI) | E-bike share |
|---|---|---|---|
| Contact / crash events | 828 | 32.0% (28.9–35.3) | 17.0% |
| Driver didn't see me | 348 | 21.6% (17.6–26.2) | 18.7% |
| Unsafe / close passing | 1,055 | 18.4% (16.2–20.8) | 17.1% |
| Failed yield at stop/intersection | 907 | 15.4% (13.2–17.9) | 17.5% |
| Harassment / aggression | 411 | 13.9% (10.9–17.5) | 17.5% |
| Infrastructure complaints | 505 | 13.9% (11.1–17.1) | 19.0% |
| Signal violations | 343 | 11.1% (8.2–14.8) | 15.5% |

- Injury × typology: χ² = 129.4, p ≈ 2e-25. Caveat: the top of the gradient
  (contact > near-miss) is near-tautological; the informative part is the ordering
  among conflict types and the typology labels themselves (e.g. harassment, n=411 —
  a category no official crash form records).
- **E-bike composition: NULL.** χ² = 2.4, p = 0.88; e-bike share flat (15.5–19.0%)
  across typologies. Well-powered at this n: e-bikes experience the same mechanism
  mix as pedal bikes. This licenses pooling mechanisms in Study 2 and kills the
  "e-bikes crash differently" hypothesis at this grain.

### Remaining Study 1 work
- Pending: `p_type` cross-tab (validity check that contact_crash is
  collision-dominated); typology map; bootstrap stability on the k=14 solution.
- Conversion to named factors (for Study 2 and the R models): per-typology binary
  flags validated on 100 hand-labeled narratives.

---

## Study 2 — E-bike severity, given the same crash (the centerpiece)

### Question
Conditional on an incident occurring, do e-bike incidents end worse than pedal-bike
incidents — overall, by rider age, and by e-bike class?

### Cohort
The Study 1 corpus (personally involved, known ebike, masked English narrative),
pooled US+Canada. ~770 e-bike, ~3,630 pedal.

### Primary analysis — ordinal severity, confounder-adjusted
1. **Outcome: ordinal, not binary.** The `injury3` ladder (no injury / injury
   untreated / injury with medical care), since an e-bike effect plausibly lives in
   the severity tail. Ordinal (proportional-odds) logistic regression.
2. **Exposure:** `ebike`, adjusted for **mechanism typology** (Study 1 labels),
   **age** (`age_imp` — the decisive confounder: e-bike riders skew older and age
   independently worsens outcomes; include `ebike × age` interaction), gender, and
   the survey fields used in `bin_logit.Rmd`.
3. Report the adjusted e-bike odds ratio with CI; proportional-odds assumption
   checked (Brant test); binary-outcome logistic as sensitivity.

### Secondary analysis — the within-e-bike class gradient
`ebike_class` (class 1 pedal-assist <20 mph / throttle <20 mph / class 3 >20 mph;
filled for ~2/3 of e-bike reports) and `ebike_speed`. Ordinal severity across
classes **within e-bikes only** — no pedal-bike confounding, same reporting
channel, and it maps directly onto the regulatory question (speed/class caps).
A monotone class gradient is the strongest policy sentence available from this
dataset; a flat one is evidence against class-based regulation. Report missingness
pattern for `ebike_class` honestly (who leaves it blank may not be random).

### Embedding-supported sensitivity analyses (embeddings as instruments, not models)
1. **Narrative-twin matching:** for each e-bike incident, the nearest pedal
   narrative by cosine similarity on masked embeddings (threshold ≥0.6; unmatched
   reported). Paired severity comparison (McNemar / Wilcoxon on the ordinal
   outcome). Matches on *everything the narrative encodes at once* — the strongest
   available control for "same crash".
2. **Discriminative probe:** classifier predicting ebike vs pedal from masked
   embeddings alone, 20-fold repeated CV. AUC ≈ 0.5 ⇒ narratives are
   linguistically indistinguishable (the composition null at every grain). AUC
   above chance ⇒ interrogate via SHAP + nearest-narrative reading; guard against
   confounds (e-bike reports skew recent and geographically — test within
   year × region strata before interpreting).
3. **Seeded hypothesis retrieval:** literature-derived mechanism seeds ("driver
   misjudged my speed and turned in front of me", "the bike was too heavy to hold
   when stopping", "throttle start surprised a pedestrian"); compare retrieval
   rates e-bike vs pedal at fixed similarity. Qualitative/supporting evidence only.

### Deliverable sentences this study is designed to produce
- "Adjusted for mechanism and age, e-bike incidents carry OR = X (CI) for higher
  injury severity" (or the null).
- "Within e-bikes, class-3/throttle incidents show [gradient / no gradient] in
  severity."
- "E-bike and pedal narratives are [indistinguishable / distinguishable] to a
  classifier" as the composition evidence.

### Effort
~1 day primary + class models (R or statsmodels; fields already prepared);
~1 day twins + probe (embeddings already computed); ~0.5 day write-up.

---

## Study 3 — Injury prediction ablation (US only, AutoML) — Esri methods demo

Unchanged in design (conditions A / C / G / CG on identical rows and 20 repeated
splits; geodemographic embeddings joined explicitly from the Living Atlas H3
layer; AutoML Basic once per condition for SHAP; pre-registered ΔAUC ≥ 0.02 rule
on C−A, G−A, CG−A, CG−C; metro-identity sensitivity check with a city fixed
effect). Cohort n ≈ 1,563 US masked narratives, all bike types. Its purpose is
the product-facing question — what do text and census-context embeddings add to
tabular prediction — not e-bike inference. Reuses Study 1's text vectors for the
US subset.

---

## Shared practicalities
- Text model pinned: `all-MiniLM-L6-v2` (384-d) via HF Text Feature Extraction
  dlpk; CPU throughout (no CUDA hardware — Intel UHD 770; the Location Encoder
  CPU patch covers any location-embedding need, and AGOL "Advanced with GPU"
  notebooks are the fallback for genuinely GPU-bound steps).
- Seeds: clustering/sampling 1208; CV splits 1–20.
- Known product issue to file with Esri: LocationEncoder.dlpk hard-codes
  `.cuda()` with no CPU fallback.
- Combined report: typology table + map (Study 1), the three e-bike deliverable
  sentences (Study 2), ΔAUC ablation table (Study 3), leakage and language
  handling as appendices.
