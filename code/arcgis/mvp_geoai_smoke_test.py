# MVP smoke test: ArcGIS GeoAI embedding tools on BikeMaps e-bike data
#
# Purpose: verify that the Pro 3.7 GeoAI embedding pipeline actually runs
# end-to-end on this project's data before building the full analysis.
# Runs in: ArcGIS Online Notebooks ("Advanced with GPU" runtime) or the
# Python/Notebook window of ArcGIS Pro 3.7 with Deep Learning Libraries.
#
# Input: mvp_sample.csv (60 e-bike incidents: 40 CA / 20 US, balanced on
# injury, each with a narrative in `details` and WGS84 x/y).
# Upload the CSV next to this notebook (AGOL: /arcgis/home/).
#
# Each step prints PASS/FAIL and continues, so one failure doesn't hide
# the status of the remaining tools. Expected wall time: ~5-15 min.

import os
import traceback

RESULTS = {}


def step(name):
    def wrap(fn):
        def run(*a, **k):
            print(f"\n=== {name} ===")
            try:
                out = fn(*a, **k)
                RESULTS[name] = "PASS"
                print(f"PASS: {name}")
                return out
            except Exception as e:
                RESULTS[name] = f"FAIL: {e}"
                traceback.print_exc()
                return None
        return run
    return wrap


# ---------------------------------------------------------------- step 0
@step("0. Environment")
def check_env():
    import arcpy
    info = arcpy.GetInstallInfo()
    print("Product:", info.get("ProductName"), info.get("Version"))
    print("License:", arcpy.ProductInfo())
    ver = tuple(int(p) for p in info.get("Version", "0.0").split(".")[:2])
    assert ver >= (3, 7), (
        f"ArcGIS Pro/runtime {info.get('Version')} < 3.7: the Embeddings "
        "Based Analysis toolset does not exist here."
    )
    geoai_tools = sorted(arcpy.ListTools("*_geoai"))
    print("GeoAI tools:", geoai_tools)
    assert geoai_tools, "GeoAI toolbox not found"
    try:
        import torch
        print("torch", torch.__version__, "| CUDA:", torch.cuda.is_available())
    except ImportError:
        print("WARNING: torch missing - Deep Learning Libraries not installed; "
              "embedding tools will fail.")
    return geoai_tools


def find_tool(geoai_tools, *keywords):
    """Resolve a GeoAI tool function by keyword, tolerant of naming drift."""
    import arcpy
    for t in geoai_tools or []:
        name = t.split("_")[0]  # e.g. 'GenerateEmbeddingsUsingAIModels_geoai'
        if all(k.lower() in name.lower() for k in keywords):
            return getattr(arcpy.geoai, name)
    raise RuntimeError(f"No GeoAI tool matching {keywords}")


# ---------------------------------------------------------------- step 1
@step("1. CSV -> point feature class")
def make_points():
    import arcpy
    home = os.getcwd() if os.path.exists("mvp_sample.csv") else "/arcgis/home"
    csv_path = os.path.join(home, "mvp_sample.csv")
    assert os.path.exists(csv_path), f"Upload mvp_sample.csv to {home}"
    gdb = os.path.join(home, "mvp_test.gdb")
    if not arcpy.Exists(gdb):
        arcpy.management.CreateFileGDB(home, "mvp_test.gdb")
    arcpy.env.workspace = gdb
    arcpy.env.overwriteOutput = True
    fc = os.path.join(gdb, "incidents")
    arcpy.management.XYTableToPoint(
        csv_path, fc, "x", "y", coordinate_system=arcpy.SpatialReference(4326)
    )
    n = int(arcpy.management.GetCount(fc)[0])
    print("Features:", n)
    assert n == 60, f"expected 60 features, got {n}"
    return fc


# ---------------------------------------------------------------- step 2
@step("2. Fetch pretrained models from Living Atlas")
def get_models():
    # Signs in as the notebook's user (AGOL) or the Pro login.
    from arcgis.gis import GIS
    gis = GIS("home")
    print("Signed in as:", gis.users.me.username)
    home = "/arcgis/home" if os.path.exists("/arcgis/home") else os.getcwd()
    wanted = {
        "text": "HF Text Feature Extraction",
        "location": "Global Location Encoder (Sentinel-2)",
    }
    paths = {}
    for key, title in wanted.items():
        hits = gis.content.search(
            f'title:"{title}" owner:esri_analytics', item_type="Deep Learning Package"
        ) or gis.content.search(f'title:"{title}"', item_type="Deep Learning Package",
                                outside_org=True)
        assert hits, f"Living Atlas item not found: {title}"
        item = hits[0]
        print(f"{key}: {item.title} ({item.id})")
        paths[key] = item.download(save_path=home)
        print("  downloaded ->", paths[key])
    return paths


# ---------------------------------------------------------------- step 3
@step("3. Text embeddings (details field)")
def text_embeddings(geoai_tools, fc, model_path):
    import arcpy
    tool = find_tool(geoai_tools, "GenerateEmbeddings")
    out_fc = fc + "_textemb"
    # Model argument names come from the dlpk; 'text_field' selects the
    # attribute to embed. If the tool errors on the argument name, print
    # the dlpk's .emd to see the expected keys.
    tool(fc, out_fc, model_path, [["text_field", "details"], ["batch_size", "4"]])
    fields = {f.name: f.type for f in arcpy.ListFields(out_fc)}
    print("Output fields:", fields)
    assert fields.get("Embedding") == "Blob", "no Blob field named 'Embedding'"
    return out_fc


# ---------------------------------------------------------------- step 4
@step("4. Extract embeddings to numeric fields")
def extract_fields(geoai_tools, emb_fc):
    import arcpy
    tool = find_tool(geoai_tools, "Extract", "Embedding")
    out_fc = emb_fc + "_flat"
    # Signature (confirmed on 3.7.1): in_features, out_features,
    # embedding_field, output_field_prefix.
    tool(emb_fc, out_fc, "Embedding", "emb")
    emb_cols = [f.name for f in arcpy.ListFields(out_fc) if "emb" in f.name.lower()
                and f.type in ("Double", "Single")]
    print(f"{len(emb_cols)} numeric embedding columns (e.g. {emb_cols[:3]})")
    assert len(emb_cols) >= 128, "expected a few hundred embedding columns"
    return out_fc, emb_cols


# ---------------------------------------------------------------- step 5
@step("5. Similarity search (injured seed)")
def similarity(geoai_tools, emb_fc):
    import arcpy
    tool = find_tool(geoai_tools, "FindSimilar", "Embedding")
    # The tool rejects in_memory query features; keep the seed in the gdb.
    seed = emb_fc + "_seed"
    arcpy.analysis.Select(emb_fc, seed, "injured = 'True'")
    print("Seed features:", arcpy.management.GetCount(seed)[0])
    out = emb_fc + "_similar"
    # Signature (confirmed on 3.7.1): embedding_features, query_features,
    # out_embeddings_feature_class, threshold (cosine similarity, 0-1).
    tool(emb_fc, seed, out, 0.5)
    print("Similar features at threshold 0.5:", arcpy.management.GetCount(out)[0])
    return out


def cpu_patch_dlpk(model_path):
    """The Global Location Encoder dlpk hard-codes .cuda(); on a CPU-only
    machine, extract it and rewrite the device calls, then return the .emd.
    The encoder is a small coordinate network, so CPU inference is fast."""
    import glob
    import zipfile
    out_dir = os.path.join(os.path.dirname(model_path), "LocationEncoder_cpu")
    if not os.path.isdir(out_dir):
        with zipfile.ZipFile(model_path) as z:  # a .dlpk is a zip archive
            z.extractall(out_dir)
        for py in glob.glob(os.path.join(out_dir, "**", "*.py"), recursive=True):
            with open(py, encoding="utf-8") as f:
                src = f.read()
            patched = (src.replace(".cuda()", ".cpu()")
                          .replace('"cuda"', '"cpu"')
                          .replace("'cuda'", "'cpu'"))
            if patched != src:
                with open(py, "w", encoding="utf-8") as f:
                    f.write(patched)
                print("CPU-patched:", os.path.basename(py))
    emds = glob.glob(os.path.join(out_dir, "**", "*.emd"), recursive=True)
    assert emds, "no .emd found inside the extracted dlpk"
    return emds[0]


# ---------------------------------------------------------------- step 6
@step("6. Location embeddings, global encoder (CA+US coverage)")
def location_embeddings(geoai_tools, fc, model_path):
    import arcpy
    import torch
    tool = find_tool(geoai_tools, "GenerateEmbeddings")
    out_fc = fc + "_locemb"
    if not torch.cuda.is_available():
        print("No CUDA GPU: patching the dlpk for CPU inference.")
        model_path = cpu_patch_dlpk(model_path)
    tool(fc, out_fc, model_path)
    # The decisive check: Canadian rows must have non-null embeddings.
    n_ca = 0
    with arcpy.da.SearchCursor(out_fc, ["country", "Embedding"]) as cur:
        for country, emb in cur:
            if country == "CA" and emb is not None:
                n_ca += 1
    print(f"Canadian points with location embedding: {n_ca}/40")
    assert n_ca >= 35, "global location encoder failed on Canadian points"
    return out_fc


# ---------------------------------------------------------------- step 7
@step("7. Train Using AutoML (basic, embeddings as predictors)")
def automl(flat_fc, emb_cols):
    import arcpy
    out_model = os.path.join(os.path.dirname(arcpy.env.workspace), "mvp_automl.dlpk")
    # 60 rows is only a smoke test of the tool, not a real model.
    arcpy.geoai.TrainUsingAutoML(
        flat_fc, out_model, "injured",
        [[c, "false"] for c in emb_cols[:50]],  # cap predictors for speed
        autoML_mode="BASIC",
    )
    print("Model written:", out_model)
    # While here, verify whether the location-embeddings option is scriptable:
    doc = arcpy.geoai.TrainUsingAutoML.__doc__ or ""
    print("'location' in TrainUsingAutoML signature docs:",
          "location" in doc.lower())
    return out_model


# ---------------------------------------------------------------- run all
tools = check_env()
fc = make_points()
models = get_models()
text_fc = text_embeddings(tools, fc, models["text"]) if (tools and fc and models) else None
flat = extract_fields(tools, text_fc) if text_fc else None
similarity(tools, text_fc) if text_fc else None
location_embeddings(tools, fc, models["location"]) if (fc and models) else None
if flat:
    automl(flat[0], flat[1])

print("\n" + "=" * 50)
print("SMOKE TEST SUMMARY")
for k, v in RESULTS.items():
    print(f"  {k}: {v}")
