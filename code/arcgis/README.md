# ArcGIS GeoAI MVP smoke test

Verifies that the ArcGIS Pro 3.7 GeoAI embedding tools run end-to-end on
BikeMaps e-bike data **without a working local ArcGIS Pro**, by using
ArcGIS Online Notebooks.

## Files

- `mvp_sample.csv` — 60 real e-bike incidents (40 Canada / 20 US, balanced
  on injury), each with the `details` narrative and WGS84 coordinates.
- `mvp_geoai_smoke_test.py` — self-verifying script; prints a PASS/FAIL
  summary per tool.

## How to run (ArcGIS Online Notebooks — no local Pro needed)

1. Sign in at arcgis.com → app launcher → **Notebooks** → new notebook.
2. Choose the **Advanced with GPU** runtime (arcpy + Deep Learning
   Libraries + GPU; required for the Global Location Encoder). "Advanced"
   without GPU is enough for the text-embedding and AutoML steps.
   Note: the runtime must be based on **Pro 3.7** — step 0 checks and
   aborts with a clear message if not.
3. In the notebook's Files pane, upload `mvp_sample.csv` to `/arcgis/home`.
4. Paste the contents of `mvp_geoai_smoke_test.py` into a cell and run.

To run in ArcGIS Pro 3.7 instead (once your install is fixed): open a
Notebook in Pro, put `mvp_sample.csv` next to the project, run the same
script. Requires Advanced license + Deep Learning Libraries.

## What each step proves

| Step | Tool under test | Pass means |
|---|---|---|
| 0 | environment | Runtime is 3.7+, GeoAI toolbox + torch present |
| 1 | XY Table To Point | Data loads as points (n=60) |
| 2 | Living Atlas access | Both pretrained .dlpk models downloadable with your credentials |
| 3 | Generate Embeddings Using AI Models (text) | `details` → BLOB `Embedding` field |
| 4 | Extract Embeddings To Fields | BLOB → numeric columns usable as predictors |
| 5 | Find Similar Features Using Embeddings | Similarity search runs on narrative embeddings |
| 6 | Generate Embeddings (Global Location Encoder) | **Canadian** points get location embeddings (the key coverage question) |
| 7 | Train Using AutoML | Classifier trains on embedding predictors; also reports whether the location-embeddings option is exposed in the arcpy signature |

## Known uncertainties the script handles

- Exact arcpy names of the new 3.7 tools: resolved at runtime from
  `arcpy.ListTools` instead of hard-coding.
- Model-argument names inside the .dlpk (e.g. `text_field`): if step 3
  errors on an argument, open the package's `.emd` to see expected keys.
- Whether "Use Location Embeddings" is scriptable in
  `arcpy.geoai.TrainUsingAutoML`: step 7 prints what the installed
  signature says.

## Interpreting results

All 7 pass → the full implementation plan
(`docs/arcgis_geoai_implementation_plan.md`) is executable; proceed to
Phase 1. Step 6 failing on Canadian points → drop the location-embedding
track for the e-bike model and rely on text embeddings (plan §5 already
covers this fallback). Step 2 failing → your account lacks access to the
pretrained packages; check Living Atlas subscription status.
