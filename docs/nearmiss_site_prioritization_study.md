# Study Design: Near-Miss-Based Site Prioritization with Mechanism Profiles

**One-line pitch:** rank cycling danger sites from crowdsourced near-miss reports
*before* injuries accumulate, attach a mechanism diagnosis to each site, and match
countermeasures — then prove the ranking works by showing early near-misses
predicted later injuries.

**Why this study:** official crash data contains only harm that already happened;
BikeMaps' near-miss reports are the only systematic record of danger before harm.
The study uses the half of the dataset the current injury models discard.

---

## Research questions

1. **RQ1 (ranking):** Which locations generate the most cycling-danger reports,
   and how stable is that ranking across reasonable weighting choices?
2. **RQ2 (mechanism):** What is mechanically wrong at each top site (dooring,
   right-hook, close pass, surface...), from structured fields plus narrative
   typologies?
3. **RQ3 (validation — the scientific claim):** Do near-miss reports predict
   where future collisions and injuries occur, better than past injuries alone?
4. **RQ4 (bonus, if data allows):** At sites where infrastructure changed during
   the study window, did report rates and mechanism mix change after?

## Design overview

Retrospective spatial cohort of all BikeMaps reports 2016-11-30 → latest pull,
analyzed within city. **Primary study area: Greater Victoria, BC** (densest
coverage); replication in the next 1–2 densest cities (candidates: Vancouver,
Kelowna — confirm from the data). Within-city analysis is the key bias control:
ranking sites against each other in one city holds the reporting culture
roughly constant, which an absolute-rate analysis cannot.

## Data

- **Incidents feed** (collisions + near-misses; the near-misses are the point —
  expect them to be the majority). Include non-personal-involvement (witness)
  reports for site counts, flagged; exclude them from injury outcomes.
- **Hazards feed** as a secondary layer (standing hazards ≠ events; never pooled
  with incidents, but shown on the same site profiles).
- Fields used: location, date, `p_type` (collision/nearmiss), `i_type`,
  `incident_with`, `injury`, `ebike`, `details` (narrative),
  `infrastructure_changed`.
- **Pull fresh data** with the existing Colab extractor — the study benefits
  from every added year, and the temporal validation needs a long window.

## Methods

### 1. Define sites (data-driven, then snapped to the network)
- Cluster report points with **DBSCAN** (eps = 40 m, minPts = 3; sensitivity at
  25/60 m). Each cluster = a candidate site; unclustered points stay in the map
  but not in the ranking.
- Snap each site to the OSM network and label it (intersection name / block),
  via osmnx (already used in this project) or ArcGIS locate tools.
- Alternative for the ArcGIS-native telling: Density-based Clustering tool,
  or Space Time Cube aggregation; same parameters, same sensitivity checks.

### 2. Rank sites (RQ1)
- **Primary metric: count of unique report-days per site** (not raw reports —
  one commuter filing three reports about one morning shouldn't triple a site;
  no reporter ID exists, so unique days is the available dedup).
- Sensitivity rankings, reported alongside: (a) severity-weighted
  (injury-collision 3, non-injury collision 2, near-miss 1); (b)
  recency-weighted (exponential decay, 3-year half-life); (c) e-bike-only.
- **Report rank stability:** Spearman correlation between the primary and each
  sensitivity ranking; a site in the top 20 under all schemes is a robust
  priority. Also report each top site's trend (reports/year slope, or ArcGIS
  Emerging Hot Spot category).

### 3. Mechanism profile per top site (RQ2)
- Structured: distribution of `incident_with`, `i_type`, turning, p_type share
  (near-miss vs collision) per site.
- Narrative: typology labels from the masked-text clustering module
  (`code/arcgis/gga_typology_module.ipynb`) joined by report id → per-site
  typology mix.
- Output: a one-line **site signature** ("Fort & Cook: 70% right-hook by
  turning vehicles, worsening") + 3 representative narrative excerpts.
- **Street-level audit:** for the top 10 sites, check imagery/street view —
  does visible geometry match the alleged mechanism? (This is the face-validity
  check a city engineer will do anyway; do it first.)

### 4. Countermeasure matching
- A fixed lookup table, mechanism → candidate treatments, cited to standard
  design guidance (NACTO Urban Bikeway Design Guide, BC Active Transportation
  Design Guide): dooring → parking-protected lane or parking removal;
  right-hook → protected intersection corner / bike signal phase; close pass →
  physical separation; surface/tracks → maintenance or crossing treatment;
  sightlines → daylighting.
- The deliverable row: site · unique-report-days · trend · dominant mechanism ·
  matched countermeasure · confidence (count + stability + audit agreement).

### 5. Validation (RQ3 — the claim that makes this publishable)
- **Temporal split:** rank sites using reports from 2016–2021 only. Outcome:
  injury collisions reported 2022–latest.
- **Test A (leading indicator):** among sites with ≥1 future injury collision,
  what share were already in the top-K of the 2016–2021 *near-miss-only*
  ranking? Report hit-rate@K for K = 10, 20, 50, with a permutation null
  (random site rankings of the same size).
- **Test B (the comparison that matters):** near-miss-only ranking vs
  past-injury-only ranking vs combined, all predicting future injury sites —
  PR-AUC / rank correlation. If near-misses add predictive value over past
  injuries, the core policy argument ("fix sites before people get hurt") has
  quantitative support. If they don't, that is a real finding about
  crowdsourced near-miss data and still publishable.
- **External check:** overlap of the top-20 with official collision data
  (ICBC crash maps for BC are public); sites BikeMaps flags that officials
  don't are the dataset's unique contribution — list them explicitly.
- Caveat to carry everywhere: both periods share reporting bias, so Test A/B
  validates *predictive* value within the reporting population, not absolute
  risk. Exposure normalization (city bike counts, Strava Metro if accessible)
  is a sensitivity analysis, not the primary design.

### 6. Before/after at changed sites (RQ4, opportunistic)
- Sites within 100 m of a known infrastructure change (the
  `infrastructure_changed` field plus the city's own project list with dates).
- Interrupted time series of monthly report counts, with 3–5 matched control
  sites (similar pre-period counts, no change) per treated site. Honest power
  note: with sparse counts this may only support descriptive before/after
  mechanism-mix comparisons — report what the n supports.

## Deliverables

1. Ranked site table (the top-20 with signatures and countermeasures) — the
   artifact a city engineer uses.
2. Map/dashboard: sites sized by score, colored by dominant mechanism,
   clickable narratives.
3. Validation note: hit-rate@K and the near-miss vs past-injury comparison.
4. Short methods paper if Test B is positive: "Crowdsourced near-misses as
   leading indicators of cycling injury locations."

## Limitations (stated up front)

- Reporting propensity confounds counts between neighborhoods; the design
  answers "where do riders report danger," mitigated by within-city ranking,
  unique-day dedup, and validation against future injuries.
- No reporter ID → imperfect dedup of serial reporters at one site.
- Victoria-centric; replication cities test generalizability.
- Site definitions depend on DBSCAN parameters → sensitivity analysis and
  network snapping reduce arbitrariness.

## Effort

| Phase | Work | Time |
|---|---|---|
| 1 | Fresh data pull, cleaning, dedup, site clustering + snapping | 2 days |
| 2 | Rankings + stability + trends | 1 day |
| 3 | Mechanism profiles (structured + typologies) + top-10 audit | 2 days |
| 4 | Validation (temporal split, Tests A/B, external overlap) | 2 days |
| 5 | Map/dashboard + ranked table + write-up | 2 days |

Total ≈ 2 weeks alongside other work. Reuses the typology module as-is; the
only new heavy computation is point clustering, which is light.
