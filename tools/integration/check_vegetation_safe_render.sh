#!/usr/bin/env bash
# Actual rendered frames, not a headless-only pass. Fresh user directory.
set -euo pipefail
godot="$(realpath "$1")"
output="$(realpath -m "$2")"
mkdir -p "$output"
isolated="$(mktemp -d)"
trap 'rm -rf "$isolated"' EXIT
export IMPERATHEN_ISOLATED_TEST=1 IMPERATHEN_VEGETATION_SAFE=1
export GODOT_SILENCE_ROOT_WARNING=1 LIBGL_ALWAYS_SOFTWARE=1
export XDG_DATA_HOME="$isolated/data" XDG_CONFIG_HOME="$isolated/config" XDG_CACHE_HOME="$isolated/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
timeout 600s xvfb-run -a -s '-screen 0 1280x1320x24' "$godot" \
  --path prototype --display-driver x11 --audio-driver Dummy \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 900x1000 --fixed-fps 60 --disable-render-loop \
  --script res://tests/vegetation_safe_test.gd -- --capture-dir="$output" \
  2>&1 | tee "$output/engine.log"
grep -q 'VEGETATION_SAFE_PASS' "$output/engine.log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|VEGETATION_SAFE_FAIL:' "$output/engine.log"; then
  echo "Rendered vegetation gate found fatal errors"
  exit 1
fi
python3 - "$output" <<'PY'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1])
report=json.loads((root/"vegetation-safe-report.json").read_text())
assert not report["failures"],report
assert report["renderer"]=="gl_compatibility",report
required={"isolated-grass-near","isolated-grass-far","isolated-herbs","isolated-tree-lod3","isolated-tree-impostor",
          "game-menu","game-prologue","game-family-handoff","game-well","game-meadow-ultra"}
samples={s["name"]:s for s in report["samples"]}
assert set(samples)==required,(required-set(samples),set(samples)-required)
for sample in samples.values():
    path=root/sample["image"]
    assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==sample["sha256"],sample
    if "stray_pixels" in sample:
        assert sample["stray_pixels"]<=4 and min(sample["pixels_per_instance"])>12,sample
    else:
        assert sample["field"]["render_path"]=="android_static",sample
print("VEGETATION_RENDER_FRAME_GATE_PASS", len(samples), "actual frames; physical Fold7 still requires retest")
PY
